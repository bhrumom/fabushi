PRAGMA foreign_keys = OFF;
BEGIN IMMEDIATE;

-- Establish the legacy v0 shape when installing into a fresh database. Existing
-- v0 databases keep their rows and are upgraded by the copy below.
CREATE TABLE IF NOT EXISTS mcp_app_identity (
  app_id TEXT PRIMARY KEY,
  repository_id TEXT,
  source_commit TEXT,
  source_type TEXT NOT NULL DEFAULT 'local-workspace',
  deployment_target TEXT NOT NULL DEFAULT 'local-only',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS mcp_app_identity_v2;
CREATE TABLE mcp_app_identity_v2 (
  schema_version INTEGER NOT NULL DEFAULT 2 CHECK (schema_version = 2),
  app_id TEXT PRIMARY KEY,
  plugin_id TEXT NOT NULL,
  author TEXT NOT NULL,
  source_host TEXT NOT NULL CHECK (source_host IN ('local', 'github')),
  source_custody TEXT NOT NULL CHECK (source_custody IN ('device', 'platform-managed', 'user-owned')),
  source_provider TEXT NOT NULL CHECK (source_provider IN ('local', 'github')),
  source_actor TEXT NOT NULL CHECK (source_actor IN ('user', 'platform')),
  source_transport TEXT NOT NULL CHECK (source_transport IN ('local-fs', 'github-mcp', 'github-app-api')),
  repository_id INTEGER,
  repository_owner TEXT,
  repository_name TEXT,
  source_commit TEXT,
  publisher TEXT NOT NULL,
  official_status TEXT NOT NULL CHECK (official_status IN ('official', 'community', 'unverified')),
  hosting_provider TEXT NOT NULL DEFAULT 'none'
    CHECK (hosting_provider IN ('none', 'github-pages', 'cloudflare-pages', 'cloudflare-workers', 'external')),
  runtime_profile TEXT NOT NULL DEFAULT 'local-web-wasm'
    CHECK (runtime_profile IN ('local-native', 'local-web-wasm', 'web-static', 'remote-edge')),
  deployment_target TEXT NOT NULL
    CHECK (deployment_target IN ('local-only', 'official-managed-github', 'user-github', 'official-source-github')),
  lineage_id TEXT NOT NULL,
  source_state TEXT NOT NULL DEFAULT 'local-only'
    CHECK (source_state IN ('local-only', 'source-hosted', 'diverged', 'failed', 'outcome-unknown')),
  web_deployment_state TEXT NOT NULL DEFAULT 'none'
    CHECK (web_deployment_state IN ('none', 'queued', 'deploying', 'deployed', 'failed', 'rolled-back')),
  source_identity_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (
    (source_host = 'local'
      AND source_custody = 'device'
      AND source_provider = 'local'
      AND source_actor = 'user'
      AND source_transport = 'local-fs'
      AND repository_id IS NULL
      AND deployment_target = 'local-only')
    OR
    (source_host = 'github'
      AND source_provider = 'github'
      AND repository_id IS NOT NULL
      AND deployment_target <> 'local-only')
  ),
  CHECK (hosting_provider <> 'none' OR web_deployment_state IN ('none', 'failed', 'rolled-back'))
);

-- v0 source_type described source custody while deployment_target described the
-- optional web host. Preserve both facts by migrating them into orthogonal fields.
INSERT INTO mcp_app_identity_v2 (
  schema_version,
  app_id,
  plugin_id,
  author,
  source_host,
  source_custody,
  source_provider,
  source_actor,
  source_transport,
  repository_id,
  repository_owner,
  repository_name,
  source_commit,
  publisher,
  official_status,
  hosting_provider,
  runtime_profile,
  deployment_target,
  lineage_id,
  source_state,
  web_deployment_state,
  source_identity_json,
  created_at,
  updated_at
)
SELECT
  2,
  app_id,
  app_id,
  'unknown',
  CASE WHEN source_type IN ('managed-github', 'user-github', 'official-github') THEN 'github' ELSE 'local' END,
  CASE
    WHEN source_type IN ('managed-github', 'official-github') THEN 'platform-managed'
    WHEN source_type = 'user-github' THEN 'user-owned'
    ELSE 'device'
  END,
  CASE WHEN source_type IN ('managed-github', 'user-github', 'official-github') THEN 'github' ELSE 'local' END,
  CASE WHEN source_type IN ('managed-github', 'official-github') THEN 'platform' ELSE 'user' END,
  CASE
    WHEN source_type IN ('managed-github', 'official-github') THEN 'github-app-api'
    WHEN source_type = 'user-github' THEN 'github-mcp'
    ELSE 'local-fs'
  END,
  CASE
    WHEN source_type IN ('managed-github', 'user-github', 'official-github') THEN CAST(repository_id AS INTEGER)
    ELSE NULL
  END,
  NULL,
  NULL,
  source_commit,
  'unknown',
  CASE WHEN source_type = 'official-github' THEN 'official' ELSE 'unverified' END,
  CASE
    WHEN deployment_target = 'github-pages' THEN 'github-pages'
    WHEN deployment_target = 'cloudflare' THEN 'cloudflare-workers'
    ELSE 'none'
  END,
  CASE
    WHEN deployment_target = 'github-pages' THEN 'web-static'
    WHEN deployment_target = 'cloudflare' THEN 'remote-edge'
    ELSE 'local-web-wasm'
  END,
  CASE
    WHEN source_type = 'managed-github' THEN 'official-managed-github'
    WHEN source_type = 'user-github' THEN 'user-github'
    WHEN source_type = 'official-github' THEN 'official-source-github'
    ELSE 'local-only'
  END,
  app_id,
  CASE WHEN source_type IN ('managed-github', 'user-github', 'official-github') THEN 'source-hosted' ELSE 'local-only' END,
  'none',
  json_object(
    'legacySourceType', source_type,
    'legacyDeploymentTarget', deployment_target,
    'repositoryId', CASE WHEN repository_id IS NULL THEN NULL ELSE CAST(repository_id AS INTEGER) END,
    'sourceCommit', source_commit
  ),
  created_at,
  updated_at
FROM mcp_app_identity;

DROP TABLE mcp_app_identity;
ALTER TABLE mcp_app_identity_v2 RENAME TO mcp_app_identity;

CREATE INDEX IF NOT EXISTS idx_mcp_app_identity_repository_id
  ON mcp_app_identity(repository_id);
CREATE INDEX IF NOT EXISTS idx_mcp_app_identity_plugin_id
  ON mcp_app_identity(plugin_id);
CREATE INDEX IF NOT EXISTS idx_mcp_app_identity_lineage_id
  ON mcp_app_identity(lineage_id);

COMMIT;
PRAGMA foreign_keys = ON;
