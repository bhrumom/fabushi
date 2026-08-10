CREATE TABLE IF NOT EXISTS mcp_app_identity (
  app_id TEXT PRIMARY KEY,
  repository_id TEXT,
  source_commit TEXT,
  source_type TEXT NOT NULL DEFAULT 'local-workspace',
  deployment_target TEXT NOT NULL DEFAULT 'local-only',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_mcp_app_identity_repository_id
  ON mcp_app_identity(repository_id);
