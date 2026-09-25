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
  ).trim().toLowerCase();
}

function normalizeStatus(body) {
  return String(body?.order_status || body?.status || "").trim().toLowerCase();
}

function getSubscription(body) {
  return body?.Subscription || body?.subscription || null;
}

function getSubscriptionId(body) {
  const subscription = getSubscription(body);
  return String(
    subscription?.id ||
      subscription?.subscription_id ||
      body?.subscription_id ||
      body?.SubscriptionId ||
      ""
  ).trim();
}

function getProductName(body) {
  const product = body?.Product || body?.product || {};
  return String(
    body?.product_name ||
      product?.product_name ||
      product?.name ||
      body?.product ||
      ""
  ).trim();
}

function getSubscriptionPlan(body) {
  const subscription = getSubscription(body);
  return subscription?.plan || body?.plan || null;
}

function normalizePlanFrequency(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function getSubscriptionLicenseType(body) {
  const plan = getSubscriptionPlan(body);
  const frequency = normalizePlanFrequency(plan?.frequency);
  const planName = normalizePlanFrequency(plan?.name);

  if (/annual|anual|yearly|year/.test(frequency)) return "annual";
  if (/monthly|mensal|month/.test(frequency)) return "monthly";
  if (/annual|anual|yearly|year/.test(planName)) return "annual";
  if (/monthly|mensal|month/.test(planName)) return "monthly";

  return null;
}

function isSubscriptionProduct(body) {
  const name = getProductName(body).toLowerCase();
  return (
    Boolean(getSubscription(body)) ||
    Boolean(getSubscriptionId(body)) ||
    /mensal|monthly|anual|annual|assinatura/.test(name)
  );
}

function parseDateToSql(value) {
  const raw = String(value || "").trim();
  if (!raw) return null;
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString().slice(0, 19).replace("T", " ");
}

function isApprovedEvent(event, status) {
  return (
    [
      "compra_aprovada",
      "purchase_approved",
      "approved",
      "order_approved",
      "subscription_renewed",
      "assinatura_renovada",
    ].includes(event) ||
    status === "paid"
  );
}

function isRevokedEvent(event, status) {
  return (
    [
      "reembolso",
      "refund",
      "refunded",
      "order_refunded",
      "chargeback",
      "chargebacked",
      "order_chargeback",
      "compra_reembolsada",
    ].includes(event) ||
    ["refunded", "chargeback", "charged_back"].includes(status)
  );
}

function isCancellationEvent(event) {
  return [
    "subscription_cancelled",
    "subscription_canceled",
    "assinatura_cancelada",
    "assinatura_canceled",
    "cancelled",
    "canceled",
  ].includes(event);
}

function getWebhookToken(request) {
  return (
    request.headers.get("x-kiwify-token") ||
    request.headers.get("x-webhook-secret") ||
    request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ||
    ""
  ).trim();
}

function bytesToHex(bytes) {
  return Array.from(new Uint8Array(bytes))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function bytesToBase64(bytes) {
  let binary = "";
  for (const byte of new Uint8Array(bytes)) binary += String.fromCharCode(byte);
  return btoa(binary);
}

async function signWebhookBody(secret, bodyText) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"]
  );
  return crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(bodyText)
  );
}

async function verifyKiwifySignature(signature, bodyText, secrets) {
  if (!signature || !bodyText || !secrets.length) return false;
  const normalized = signature.trim();
  for (const secret of secrets) {
    const digest = await signWebhookBody(secret, bodyText);
    if (
      normalized === bytesToHex(digest) ||
      normalized === bytesToBase64(digest)
    ) {
      return true;
    }
  }
  return false;
}

function customerData(body) {
  const customer = body?.Customer || body?.customer || {};
  return {
    email: String(customer?.email || body?.email || "").trim().toLowerCase(),
    name: String(
      customer?.full_name ||
        customer?.name ||
        body?.name ||
        ""
    ).trim(),
  };
}

function transactionIdFrom(body) {
  return String(
    body?.order_id ||
      body?.transaction_id ||
      body?.purchase_id ||
      body?.id ||
      ""
  ).trim();
}

async function findLicense(env, { transactionId = "", subscriptionId = "" } = {}) {
  if (subscriptionId) {
    const bySubscription = await env.DB.prepare(
      "SELECT * FROM licenses WHERE subscription_id = ?1 LIMIT 1"
    ).bind(subscriptionId).first();
    if (bySubscription) return bySubscription;
  }
  if (transactionId) {
    const byTransaction = await env.DB.prepare(
      "SELECT * FROM licenses WHERE transaction_id = ?1 LIMIT 1"
    ).bind(transactionId).first();
    if (byTransaction) return byTransaction;
  }
  return null;
}

async function ensureUniqueKey(env) {
  for (let attempt = 0; attempt < 8; attempt++) {
    const licenseKey = makeKey();
    const collision = await env.DB.prepare(
      "SELECT id FROM licenses WHERE license_key = ?1 LIMIT 1"
    ).bind(licenseKey).first();
    if (!collision) return licenseKey;
  }
  throw new Error("license_key_generation_failed");
}

async function upsertApproved(body, env) {
  const transactionId = transactionIdFrom(body);
  if (!transactionId) return json({ error: "transaction_id_required" }, 400);

  const subscriptionId = getSubscriptionId(body);
  const subscriptionProduct = isSubscriptionProduct(body);
  const subscription = getSubscription(body);
  const expiresAt = subscriptionProduct
    ? parseDateToSql(
        subscription?.next_payment ||
          subscription?.nextPayment ||
          body?.next_payment ||
          body?.subscription_next_payment
      )
    : null;

  if (subscriptionProduct && !subscriptionId) {
    return json({ error: "subscription_id_required" }, 400);
  }
  if (subscriptionProduct && !expiresAt) {
    return json({ error: "subscription_expiration_required" }, 400);
  }

  const licenseType = subscriptionProduct ? getSubscriptionLicenseType(body) : "lifetime";
  if (subscriptionProduct && !licenseType) {
    const plan = getSubscriptionPlan(body);
    return json({
      ok: true,
      ignored: true,
      reason: "unsupported_subscription_plan_frequency",
      frequency: normalizePlanFrequency(plan?.frequency),
      plan_name: normalizePlanFrequency(plan?.name),
    });
  }

  const customer = customerData(body);
  const productName = getProductName(body);
  const existing = await findLicense(env, { transactionId, subscriptionId });

  if (existing) {
    await env.DB.prepare(
      `UPDATE licenses
       SET buyer_email = COALESCE(?1, buyer_email),
           buyer_name = COALESCE(?2, buyer_name),
           product_name = COALESCE(?3, product_name),
           license_type = ?4,
           status = 'active',
           subscription_id = COALESCE(?5, subscription_id),
           last_payment_id = ?6,
           expires_at = ?7,
           cancelled_at = NULL,
           revoked_at = NULL
       WHERE id = ?8`
    ).bind(
      customer.email || null,
      customer.name || null,
      productName || null,
      licenseType,
      subscriptionId || null,
      transactionId,
      subscriptionProduct ? expiresAt : null,
      existing.id
    ).run();

    return json({
      ok: true,
      license_key: existing.license_key,
      existing: true,
      license_type: licenseType,
      expires_at: subscriptionProduct ? expiresAt : null,
    });
  }

  const licenseKey = await ensureUniqueKey(env);
  await env.DB.prepare(
    `INSERT INTO licenses
      (license_key, transaction_id, buyer_email, buyer_name, product_name,
       license_type, status, subscription_id, last_payment_id, expires_at, created_at)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, 'active', ?7, ?8, ?9, datetime('now'))`
  ).bind(
    licenseKey,
    transactionId,
    customer.email || null,
    customer.name || null,
    productName || null,
    licenseType,
    subscriptionId || null,
    transactionId,
    subscriptionProduct ? expiresAt : null
  ).run();

  return json({
    ok: true,
    license_key: licenseKey,
    created: true,
    license_type: licenseType,
    expires_at: subscriptionProduct ? expiresAt : null,
  });
}

async function revokeLicense(body, env) {
  const transactionId = transactionIdFrom(body);
  const subscriptionId = getSubscriptionId(body);
  const license = await findLicense(env, { transactionId, subscriptionId });
  if (!license) {
    return json({ ok: true, revoked: false, ignored: true });
  }

  await env.DB.prepare(
    "UPDATE licenses SET status='revoked', revoked_at=datetime('now') WHERE id=?1"
  ).bind(license.id).run();

  return json({ ok: true, revoked: true });
}

async function cancelSubscription(body, env) {
  const transactionId = transactionIdFrom(body);
  const subscriptionId = getSubscriptionId(body);
  const license = await findLicense(env, { transactionId, subscriptionId });
  if (!license) {
    return json({ ok: true, cancelled: false, ignored: true });
  }

  await env.DB.prepare(
    `UPDATE licenses
     SET cancelled_at = datetime('now'),
         status = CASE
           WHEN license_type IN ('monthly','annual') AND expires_at IS NOT NULL AND expires_at <= datetime('now')
             THEN 'expired'
           ELSE status
         END
     WHERE id=?1`
  ).bind(license.id).run();

  return json({
    ok: true,
    cancelled: true,
    expires_at: license.expires_at || null,
  });
}

async function handleWebhook(request, env) {
  const configuredSecrets = [
    env.KIWIFY_WEBHOOK_SECRET,
    env.KIWIFY_WEBHOOK_SECRET_2,
    env.KIWIFY_WEBHOOK_SECRET_3,
    ...(String(env.KIWIFY_WEBHOOK_SECRETS || "")
      .split(/[,\\n]/)
      .map((value) => value.trim())
      .filter(Boolean)),
  ].filter(Boolean);

  if (!configuredSecrets.length) return json({ error: "Webhook secret not configured" }, 500);

  const url = new URL(request.url);
  const signature = String(url.searchParams.get("signature") || "").trim();
  const headerToken = getWebhookToken(request);

  let bodyText;
  try {
    bodyText = await request.text();
  } catch {
    return json({ error: "Invalid body" }, 400);
  }

  const signatureValid = await verifyKiwifySignature(
    signature,
    bodyText,
    configuredSecrets
  );
  const legacyTokenValid =
    Boolean(headerToken) && configuredSecrets.includes(headerToken);

  if (!signatureValid && !legacyTokenValid) {
    return json({ error: "Unauthorized" }, 401);
  }

  let body;
  try {
    body = JSON.parse(bodyText);
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const event = normalizeEvent(body);
  const status = normalizeStatus(body);

  if (isRevokedEvent(event, status)) {
    return revokeLicense(body, env);
  }

  if (isCancellationEvent(event)) {
    return cancelSubscription(body, env);
  }

  if (isApprovedEvent(event, status)) {
    return upsertApproved(body, env);
  }

  return json({ ok: true, ignored: true, event, status });
}

async function licenseForRequest(body, env) {
  const key = String(body?.license_key || "").trim().toUpperCase();
  if (!key) return { error: "license_key_required", status: 400 };

  const license = await env.DB.prepare(
    "SELECT * FROM licenses WHERE license_key=?1 LIMIT 1"
  ).bind(key).first();

  if (!license) return { error: "invalid_license", status: 404 };
  if (license.status === "revoked") return { error: "license_revoked", status: 403 };

  if (
    ["monthly", "annual"].includes(license.license_type) &&
    (!license.expires_at || license.expires_at <= new Date().toISOString().slice(0, 19).replace("T", " "))
  ) {
    await env.DB.prepare(
      "UPDATE licenses SET status='expired' WHERE id=?1 AND status='active'"
    ).bind(license.id).run();
    return { error: "license_expired", status: 403 };
  }

  return { license };
}

async function activate(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const installationId = String(body?.installation_id || "").trim();
  if (!installationId) return json({ error: "installation_id is required" }, 400);

  const lookup = await licenseForRequest(body, env);
  if (lookup.error) return json({ error: lookup.error }, lookup.status);

  const license = lookup.license;
  if (license.installation_id && license.installation_id !== installationId) {
    return json({ error: "license_already_activated" }, 409);
  }

  if (!license.installation_id) {
    await env.DB.prepare(
      "UPDATE licenses SET installation_id=?1, activated_at=COALESCE(activated_at, datetime('now')) WHERE id=?2"
    ).bind(installationId, license.id).run();
  }

  return json({
    ok: true,
    activated: true,
    license_key: license.license_key,
    license_type: license.license_type,
    expires_at: license.expires_at || null,
    cancelled_at: license.cancelled_at || null,
    server_time: new Date().toISOString(),
  });
}

async function validate(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const installationId = String(body?.installation_id || "").trim();
  if (!installationId) return json({ error: "installation_id is required" }, 400);

  const lookup = await licenseForRequest(body, env);
  if (lookup.error) return json({ error: lookup.error }, lookup.status);

  const license = lookup.license;
  if (license.installation_id && license.installation_id !== installationId) {
    return json({ error: "license_already_activated" }, 409);
  }

  if (!license.installation_id) {
    await env.DB.prepare(
      "UPDATE licenses SET installation_id=?1, activated_at=COALESCE(activated_at, datetime('now')) WHERE id=?2"
    ).bind(installationId, license.id).run();
  }

  return json({
    ok: true,
    valid: true,
    license_key: license.license_key,
    license_type: license.license_type,
    expires_at: license.expires_at || null,
    cancelled_at: license.cancelled_at || null,
    server_time: new Date().toISOString(),
  });
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
    "SELECT license_key, status, license_type, expires_at, cancelled_at FROM licenses WHERE transaction_id=?1 AND lower(buyer_email)=?2 LIMIT 1"
  ).bind(orderId, email).first();

  if (!license) return json({ error: "purchase_not_found" }, 404);
  if (license.status === "revoked") return json({ error: "license_revoked" }, 403);
  if (["monthly", "annual"].includes(license.license_type) && (!license.expires_at || license.expires_at <= new Date().toISOString().slice(0, 19).replace("T", " "))) {
    return json({ error: "license_expired" }, 403);
  }

  return json({
    ok: true,
    license_key: license.license_key,
    license_type: license.license_type,
    expires_at: license.expires_at || null,
  });
}

const claimPage = `<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Chave do Poliroutines</title>
<style>
body{font-family:system-ui,-apple-system,Segoe UI,sans-serif;background:#f7f5fa;margin:0;min-height:100vh;display:grid;place-items:center;color:#222}
.card{width:min(92vw,500px);background:#fff;border-radius:24px;padding:28px;box-shadow:0 12px 40px #0001;box-sizing:border-box}
.brand{font-weight:950;letter-spacing:.03em;color:#4f378b}.sub{color:#666;line-height:1.5}label{display:block;margin:16px 0 6px;font-weight:700}input{width:100%;box-sizing:border-box;padding:14px;border:1px solid #ddd;border-radius:12px;font-size:16px}button{width:100%;margin-top:20px;padding:14px;border:0;border-radius:12px;background:#6750a4;color:white;font-size:16px;font-weight:700;cursor:pointer}.key{margin-top:20px;padding:18px;border-radius:14px;background:#f0ecf8;text-align:center;font-size:20px;font-weight:800;letter-spacing:1px;word-break:break-word}.error{color:#b3261e;margin-top:14px}.small{font-size:13px;color:#777;margin-top:14px}.download{display:block;margin-top:12px;text-align:center;color:#4f378b;font-weight:800}
</style></head>
<body><main class="card">
<div class="brand">POLIROUTINES</div>
<h1>Chave de ativação</h1>
<p class="sub">Informe o e-mail usado na compra e o ID do pedido para consultar sua licença.</p>
<label for="email">E-mail da compra</label><input id="email" type="email" autocomplete="email" placeholder="seu@email.com">
<label for="order">ID do pedido</label><input id="order" autocomplete="off" placeholder="Ex.: 123456789">
<button id="btn" onclick="claim()">Consultar licença</button><div id="result"></div>
<a class="download" href="https://brunopolii.github.io/app-do-poli/download.html">Baixar o APK do Poliroutines</a>
<p class="small">A chave fica vinculada ao primeiro aparelho em que for ativada.</p>
<script>
async function claim(){
const btn=document.getElementById('btn'),result=document.getElementById('result');btn.disabled=true;result.textContent='Consultando...';
try{
const r=await fetch('/claim',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:document.getElementById('email').value,order_id:document.getElementById('order').value})});
const d=await r.json();
if(!r.ok)throw new Error(d.error==='purchase_not_found'?'Compra não encontrada. Confira o e-mail e o ID do pedido.':d.error==='license_expired'?'Esta assinatura expirou. Faça uma nova renovação.':d.error||'Não foi possível consultar a licença.');
result.innerHTML='<div class="key">'+d.license_key+'</div>';
}catch(e){result.innerHTML='<div class="error">'+e.message+'</div>';}
finally{btn.disabled=false;}
}
</script></main></body></html>`;

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return cors(new Response(null, { status: 204 }));
    const url = new URL(request.url);
    let response;

    if (url.pathname === "/health") {
      response = json({ ok: true, service: "poliroutines-license", version: "6" });
    } else if (url.pathname === "/webhook" && request.method === "POST") {
      response = await handleWebhook(request, env);
    } else if (url.pathname === "/activate" && request.method === "POST") {
      response = await activate(request, env);
    } else if (url.pathname === "/validate" && request.method === "POST") {
      response = await validate(request, env);
    } else if (url.pathname === "/claim" && request.method === "GET") {
      response = new Response(claimPage, {
        headers: {
          "content-type": "text/html; charset=utf-8",
          "cache-control": "no-store",
        },
      });
    } else if (url.pathname === "/claim" && request.method === "POST") {
      response = await claim(request, env);
    } else if (url.pathname === "/" || url.pathname === "") {
      response = json({
        ok: true,
        service: "poliroutines-license",
        status: "online",
        endpoints: ["/health", "/webhook", "/activate", "/validate", "/claim"],
      });
    } else {
      response = json({ error: "not_found" }, 404);
    }

    return cors(response);
  },
};
