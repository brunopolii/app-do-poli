const json = (data, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });

const cors = (response) => {
  response.headers.set("access-control-allow-origin", "*");
  response.headers.set("access-control-allow-methods", "GET,POST,OPTIONS");
  response.headers.set("access-control-allow-headers", "content-type,x-webhook-secret");
  return response;
};

function makeKey() {
  const bytes = crypto.getRandomValues(new Uint8Array(12));
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let value = "";
  for (const byte of bytes) value += alphabet[byte % alphabet.length];
  return `POLI-${value.slice(0, 4)}-${value.slice(4, 8)}-${value.slice(8, 12)}`;
}

function normalizeEvent(body) {
  return String(body?.webhook_event_type || body?.event || body?.type || "").toLowerCase();
}

async function handleWebhook(request, env) {
  const configuredSecret = env.KIWIFY_WEBHOOK_SECRET;
  if (!configuredSecret) return json({ error: "Webhook secret not configured" }, 500);

  const suppliedSecret = request.headers.get("x-webhook-secret") ||
    request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  if (suppliedSecret !== configuredSecret) return json({ error: "Unauthorized" }, 401);

  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const event = normalizeEvent(body);
  const transactionId = String(
    body?.order_id || body?.transaction_id || body?.purchase_id || body?.id || crypto.randomUUID()
  );
  const email = String(body?.Customer?.email || body?.customer?.email || body?.email || "").trim().toLowerCase();
  const name = String(body?.Customer?.full_name || body?.customer?.name || body?.name || "").trim();

  if (["compra_aprovada", "purchase_approved", "approved", "order_approved"].includes(event)) {
    const existing = await env.DB.prepare("SELECT license_key FROM licenses WHERE transaction_id = ?1")
      .bind(transactionId).first();
    if (existing) return json({ ok: true, license_key: existing.license_key, existing: true });

    let licenseKey = makeKey();
    for (let attempt = 0; attempt < 5; attempt++) {
      const collision = await env.DB.prepare("SELECT id FROM licenses WHERE license_key = ?1").bind(licenseKey).first();
      if (!collision) break;
      licenseKey = makeKey();
    }

    await env.DB.prepare(
      `INSERT INTO licenses (license_key, transaction_id, buyer_email, buyer_name, status, created_at)
       VALUES (?1, ?2, ?3, ?4, 'active', datetime('now'))`
    ).bind(licenseKey, transactionId, email, name).run();

    return json({ ok: true, license_key: licenseKey, created: true });
  }

  if (["reembolso", "refund", "chargeback", "chargebacked", "compra_reembolsada"].includes(event)) {
    await env.DB.prepare(
      "UPDATE licenses SET status = 'revoked', revoked_at = datetime('now') WHERE transaction_id = ?1"
    ).bind(transactionId).run();
    return json({ ok: true, revoked: true });
  }

  return json({ ok: true, ignored: true, event });
}

async function activate(request, env) {
  let body;
  try { body = await request.json(); } catch { return json({ error: "Invalid JSON" }, 400); }
  const key = String(body?.license_key || "").trim().toUpperCase();
  const installationId = String(body?.installation_id || "").trim();
  if (!key || !installationId) return json({ error: "license_key and installation_id are required" }, 400);

  const license = await env.DB.prepare("SELECT * FROM licenses WHERE license_key = ?1").bind(key).first();
  if (!license) return json({ error: "invalid_license" }, 404);
  if (license.status !== "active") return json({ error: "license_revoked" }, 403);

  if (license.installation_id && license.installation_id !== installationId) {
    return json({ error: "license_already_activated" }, 409);
  }

  if (!license.installation_id) {
    await env.DB.prepare(
      "UPDATE licenses SET installation_id = ?1, activated_at = datetime('now') WHERE id = ?2"
    ).bind(installationId, license.id).run();
  }

  return json({ ok: true, activated: true, license_key: key });
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return cors(new Response(null, { status: 204 }));
    const url = new URL(request.url);
    let response;
    if (url.pathname === "/health") response = json({ ok: true, service: "polirotinas-license" });
    else if (url.pathname === "/webhook" && request.method === "POST") response = await handleWebhook(request, env);
    else if (url.pathname === "/activate" && request.method === "POST") response = await activate(request, env);
    else response = json({ error: "not_found" }, 404);
    return cors(response);
  },
};
