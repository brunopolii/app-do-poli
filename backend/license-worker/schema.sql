CREATE TABLE IF NOT EXISTS licenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  license_key TEXT NOT NULL UNIQUE,
  transaction_id TEXT NOT NULL UNIQUE,
  buyer_email TEXT,
  buyer_name TEXT,
  product_name TEXT,
  license_type TEXT NOT NULL DEFAULT 'lifetime',
  status TEXT NOT NULL DEFAULT 'active',
  subscription_id TEXT,
  last_payment_id TEXT,
  expires_at TEXT,
  cancelled_at TEXT,
  installation_id TEXT UNIQUE,
  created_at TEXT NOT NULL,
  activated_at TEXT,
  revoked_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_licenses_transaction_id ON licenses(transaction_id);
CREATE INDEX IF NOT EXISTS idx_licenses_status ON licenses(status);
CREATE INDEX IF NOT EXISTS idx_licenses_subscription_id ON licenses(subscription_id);
CREATE INDEX IF NOT EXISTS idx_licenses_expires_at ON licenses(expires_at);

CREATE TABLE IF NOT EXISTS license_deliveries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_id TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL,
  license_key TEXT NOT NULL,
  sent_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_license_deliveries_transaction_id ON license_deliveries(transaction_id);
CREATE INDEX IF NOT EXISTS idx_license_deliveries_license_key ON license_deliveries(license_key);