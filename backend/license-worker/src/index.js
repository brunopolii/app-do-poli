const json = (data, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });

const cors = (response) => {
  response.headers.set("access-control-allow-origin", "*");
  response.headers.set("access-control-allow-methods", "GET,POST,OPTIONS");
  response.headers.set(
    "access-control-allow-headers",
    "content-type,x-kiwify-token,x-webhook-secret,authorization"
  );
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
  return String(
    body?.webhook_event_type || body?.event || body?.type || body?.trigger || ""
  ).toLowerCase();
}

function getWebhookToken(request) {
  return (
    request.headers.get("x-kiwify-token") ||
    request.headers.get("x-webhook-secret") ||
    request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ||
    ""
  ).trim();
}

async function handleWebhook(request, env) {
  const configuredSecret = String(env.KIWIFY_WEBHOOK_SECRET || "").trim();
  if (!configuredSecret) return json({ error: "Webhook secret not configured" }, 500);

  const suppliedSecret = getWebhookToken(request);
  if (!suppliedSecret || suppliedSecret !== configuredSecret) {
    return json({ error: "Unauthorized" }, 401);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const event = normalizeEvent(body);
  const transactionId = String(
    body?.order_id ||
      body?.transaction_id ||
      body?.purchase_id ||
      body?.id ||
      crypto.randomUUID()
  );
  const email = String(
    body?.Customer?.email || body?.customer?.email || body?.email || ""
  )
    .trim()
    .toLowerCase();
  const name = String(
    body?.Customer?.full_name || body?.customer?.name || body?.name || ""
  ).trim();

  if (["compra_aprovada", "purchase_approved", "approved", "order_approved"].includes(event)) {
    const existing = await env.DB.prepare(
      "SELECT license_key FROM licenses WHERE transaction_id = ?1"
    )
      .bind(transactionId)
      .first();
    if (existing) return json({ ok: true, license_key: existing.license_key, existing: true });

    let licenseKey = makeKey();
    for (let attempt = 0; attempt < 5; attempt++) {
      const collision = await env.DB.prepare(
        "SELECT id FROM licenses WHERE license_key = ?1"
      )
        .bind(licenseKey)
        .first();
      if (!collision) break;
      licenseKey = makeKey();
    }

    await env.DB.prepare(
      `INSERT INTO licenses (license_key, transaction_id, buyer_email, buyer_name, status, created_at)
       VALUES (?1, ?2, ?3, ?4, 'active', datetime('now'))`
    )
      .bind(licenseKey, transactionId, email, name)
      .run();

    return json({ ok: true, license_key: licenseKey, created: true });
  }

  if (
    [
      "reembolso",
      "refund",
      "refunded",
      "order_refunded",
      "chargeback",
      "chargebacked",
      "order_chargeback",
      "compra_reembolsada",
    ].includes(event)
  ) {
    await env.DB.prepare(
      "UPDATE licenses SET status = 'revoked', revoked_at = datetime('now') WHERE transaction_id = ?1"
    )
      .bind(transactionId)
      .run();
    return json({ ok: true, revoked: true });
  }

  return json({ ok: true, ignored: true, event });
}

async function activate(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }
  const key = String(body?.license_key || "").trim().toUpperCase();
  const installationId = String(body?.installation_id || "").trim();
  if (!key || !installationId) {
    return json({ error: "license_key and installation_id are required" }, 400);
  }

  const license = await env.DB.prepare(
    "SELECT * FROM licenses WHERE license_key = ?1"
  )
    .bind(key)
    .first();
  if (!license) return json({ error: "invalid_license" }, 404);
  if (license.status !== "active") return json({ error: "license_revoked" }, 403);

  if (license.installation_id && license.installation_id !== installationId) {
    return json({ error: "license_already_activated" }, 409);
  }

  if (!license.installation_id) {
    await env.DB.prepare(
      "UPDATE licenses SET installation_id = ?1, activated_at = datetime('now') WHERE id = ?2"
    )
      .bind(installationId, license.id)
      .run();
  }

  return json({ ok: true, activated: true, license_key: key });
}

async function claim(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const email = String(body?.email || "").trim().toLowerCase();
  const orderId = String(body?.order_id || "").trim();
  if (!email || !orderId) return json({ error: "email_and_order_id_required" }, 400);

  const license = await env.DB.prepare(
    "SELECT license_key, status FROM licenses WHERE transaction_id = ?1 AND lower(buyer_email) = ?2"
  )
    .bind(orderId, email)
    .first();

  if (!license) return json({ error: "purchase_not_found" }, 404);
  if (license.status !== "active") return json({ error: "license_revoked" }, 403);

  return json({ ok: true, license_key: license.license_key });
}

const claimPage = `<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Ativar Polirotinas</title>
<style>
body{font-family:system-ui,-apple-system,Segoe UI,sans-serif;background:#f7f5fa;margin:0;min-height:100vh;display:grid;place-items:center;color:#222}
.card{width:min(92vw,460px);background:#fff;border-radius:24px;padding:28px;box-shadow:0 12px 40px #0001;box-sizing:border-box}
h1{margin:0 0 8px}p{color:#666;line-height:1.5}label{display:block;margin:16px 0 6px;font-weight:600}input{width:100%;box-sizing:border-box;padding:14px;border:1px solid #ddd;border-radius:12px;font-size:16px}button{width:100%;margin-top:20px;padding:14px;border:0;border-radius:12px;background:#6750a4;color:white;font-size:16px;font-weight:700;cursor:pointer}.key{margin-top:20px;padding:18px;border-radius:14px;background:#f0ecf8;text-align:center;font-size:20px;font-weight:800;letter-spacing:1px;word-break:break-word}.error{color:#b3261e;margin-top:14px}.small{font-size:13px;color:#777}
</style></head>
<body><main class="card"><h1>Chave do Polirotinas</h1><p>Informe o e-mail usado na compra e o ID do pedido para consultar sua chave de ativação.</p>
<label for="email">E-mail da compra</label><input id="email" type="email" autocomplete="email" placeholder="seu@email.com">
<label for="order">ID do pedido</label><input id="order" autocomplete="off" placeholder="Ex.: 123456789">
<button id="btn" onclick="claim()">Mostrar minha chave</button><div id="result"></div>
<p class="small">A chave é vinculada ao primeiro aparelho em que for ativada.</p></main>
<script>
async function claim(){const btn=document.getElementById('btn'),result=document.getElementById('result');btn.disabled=true;result.textContent='Consultando...';try{const r=await fetch('/claim',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:document.getElementById('email').value,order_id:document.getElementById('order').value})});const d=await r.json();if(!r.ok)throw new Error(d.error==='purchase_not_found'?'Compra não encontrada. Confira o e-mail e o ID do pedido.':d.error||'Não foi possível consultar a compra.');result.innerHTML='<div class="key">'+d.license_key+'</div>';}catch(e){result.innerHTML='<div class="error">'+e.message+'</div>';}finally{btn.disabled=false;}}
</script></body></html>`;

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return cors(new Response(null, { status: 204 }));
    const url = new URL(request.url);
    let response;
    if (url.pathname === "/health") {
      response = json({ ok: true, service: "polirotinas-license", version: "3" });
    } else if (url.pathname === "/webhook" && request.method === "POST") {
      response = await handleWebhook(request, env);
    } else if (url.pathname === "/activate" && request.method === "POST") {
      response = await activate(request, env);
    } else if (url.pathname === "/claim" && request.method === "GET") {
      response = new Response(claimPage, {
        headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" },
      });
    } else if (url.pathname === "/claim" && request.method === "POST") {
      response = await claim(request, env);
    } else if (url.pathname === "/" || url.pathname === "") {
      response = json({ ok: true, service: "polirotinas-license", status: "online", endpoints: ["/health", "/webhook", "/activate", "/claim"] });
    } else {
      response = json({ error: "not_found" }, 404);
    }
    return cors(response);
  },
};
