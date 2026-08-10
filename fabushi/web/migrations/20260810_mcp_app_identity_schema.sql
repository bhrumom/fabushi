-- T01.1 identity-schema: keep source ownership and deployment identity orthogonal.
CREATE TABLE IF NOT EXISTS mcp_app_identities (
  app_id TEXT PRIMARY KEY,
  plugin_id TEXT NOT NULL UNIQUE,
  author_subject_id TEXT NOT NULL,
  source_host TEXT NOT NULL CHECK (source_host IN ('local','github')),
  source_custody TEXT NOT NULL CHECK (source_custody IN ('device','platform-managed','user-owned')),
  repository_id INTEGER,
  repository_owner TEXT,
  repository_name TEXT,
  publisher_subject_id TEXT,
  official_status TEXT NOT NULL CHECK (official_status IN ('official','community','unverified')),
  lineage_id TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS mcp_app_source_bindings (
  source_binding_id TEXT PRIMARY KEY,
  app_id TEXT NOT NULL REFERENCES mcp_app_identities(app_id),
  provider TEXT NOT NULL CHECK (provider IN ('local','github')),
  actor TEXT NOT NULL CHECK (actor IN ('user','platform')),
  transport TEXT NOT NULL CHECK (transport IN ('local-fs','github-mcp','github-app-api')),
  repository_id INTEGER,
  commit_sha TEXT,
  tree_hash TEXT
);

CREATE TABLE IF NOT EXISTS mcp_app_web_deployments (
  deployment_id TEXT PRIMARY KEY,
  app_id TEXT NOT NULL REFERENCES mcp_app_identities(app_id),
  hosting_provider TEXT NOT NULL CHECK (hosting_provider IN ('none','github-pages','cloudflare-pages','cloudflare-workers','external')),
  runtime_profile TEXT NOT NULL,
  state TEXT NOT NULL
);
