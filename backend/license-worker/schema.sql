CREATE TABLE IF NOT EXISTS licenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  license_key TEXT NOT NULL UNIQUE,
  transaction_id TEXT NOT NULL UNIQUE,
  buyer_email TEXT,
  buyer_name TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  installation_id TEXT UNIQUE,
  created_at TEXT NOT NULL,
  activated_at TEXT,
  revoked_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_licenses_transaction_id ON licenses(transaction_id);
CREATE INDEX IF NOT EXISTS idx_licenses_status ON licenses(status);
