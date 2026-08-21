CREATE TABLE IF NOT EXISTS transfer_receipt_claims (
  jti TEXT PRIMARY KEY,
  account_user_id TEXT,
  username TEXT,
  bytes INTEGER NOT NULL CHECK (bytes > 0),
  expires_at INTEGER NOT NULL,
  claimed_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_transfer_receipt_claims_expires_at
  ON transfer_receipt_claims (expires_at);
