-- T01.1 identity-schema: keep source custody and deployment facts orthogonal.
CREATE TABLE IF NOT EXISTS mcp_app_identity (
  app_id TEXT PRIMARY KEY,
  plugin_id TEXT NOT NULL,
  author_subject_id TEXT NOT NULL,
  source_host TEXT NOT NULL CHECK (source_host IN ('local','github')),
  source_custody TEXT NOT NULL CHECK (source_custody IN ('device','platform-managed','user-owned')),
  source_provider TEXT,
  source_actor TEXT,
  source_transport TEXT,
  repository_id INTEGER,
  repository_owner TEXT,
  repository_name TEXT,
  publisher_subject_id TEXT,
  official_status TEXT NOT NULL CHECK (official_status IN ('official','community','unverified')),
  hosting_provider TEXT NOT NULL DEFAULT 'none',
  runtime_profile TEXT NOT NULL,
  deployment_target TEXT,
  lineage_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_mcp_app_identity_repository
ON mcp_app_identity(repository_id);
