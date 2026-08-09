ALTER TABLE marketplace_plugins ADD COLUMN author TEXT NOT NULL DEFAULT '';
ALTER TABLE marketplace_plugins ADD COLUMN source_host TEXT NOT NULL DEFAULT 'local'
  CHECK (source_host IN ('local','github'));
ALTER TABLE marketplace_plugins ADD COLUMN source_custody TEXT NOT NULL DEFAULT 'device'
  CHECK (source_custody IN ('device','platform-managed','user-owned'));
ALTER TABLE marketplace_plugins ADD COLUMN source_provider TEXT NOT NULL DEFAULT 'local'
  CHECK (source_provider IN ('local','github'));
ALTER TABLE marketplace_plugins ADD COLUMN source_actor TEXT NOT NULL DEFAULT 'user'
  CHECK (source_actor IN ('user','platform'));
ALTER TABLE marketplace_plugins ADD COLUMN source_transport TEXT NOT NULL DEFAULT 'local-fs'
  CHECK (source_transport IN ('local-fs','github-mcp','github-app-api'));
ALTER TABLE marketplace_plugins ADD COLUMN repository_owner TEXT;
ALTER TABLE marketplace_plugins ADD COLUMN repository_name TEXT;
ALTER TABLE marketplace_plugins ADD COLUMN repository_id INTEGER;
ALTER TABLE marketplace_plugins ADD COLUMN publisher TEXT NOT NULL DEFAULT '';
ALTER TABLE marketplace_plugins ADD COLUMN official_status TEXT NOT NULL DEFAULT 'unverified'
  CHECK (official_status IN ('official','community','unverified'));
ALTER TABLE marketplace_plugins ADD COLUMN hosting_provider TEXT NOT NULL DEFAULT 'none'
  CHECK (hosting_provider IN ('none','github-pages','cloudflare-pages','cloudflare-workers','external'));
ALTER TABLE marketplace_plugins ADD COLUMN runtime_profile TEXT NOT NULL DEFAULT 'local-web-wasm'
  CHECK (runtime_profile IN ('local-native','local-web-wasm','web-static','remote-edge'));
ALTER TABLE marketplace_plugins ADD COLUMN deployment_target TEXT NOT NULL DEFAULT 'local-only'
  CHECK (deployment_target IN ('local-only','official-managed-github','user-github','official-source-github'));
ALTER TABLE marketplace_plugins ADD COLUMN source_identity_json TEXT NOT NULL DEFAULT '{}';

-- Existing releases predate the explicit source-identity model. Preserve the
-- complete old source object byte-for-byte and conservatively classify any
-- record with a GitHub repository as user-owned until an authoritative
-- reconciliation proves otherwise. Never infer official identity, hosting, or
-- runtime deployment from repository ownership or a source-hosted state.
UPDATE marketplace_plugins
   SET author = CASE WHEN author = '' THEN publisher_user_id ELSE author END,
       publisher = CASE WHEN publisher = '' THEN publisher_user_id ELSE publisher END,
       source_identity_json = COALESCE(
         (SELECT r.source_json
            FROM plugin_releases r
           WHERE r.plugin_id = marketplace_plugins.plugin_id
             AND r.source_json <> '{}'
           ORDER BY r.published_at DESC
           LIMIT 1),
         source_identity_json
       );

UPDATE marketplace_plugins
   SET source_host = 'github',
       source_custody = 'user-owned',
       source_provider = 'github',
       source_actor = 'user',
       source_transport = 'github-mcp',
       deployment_target = 'user-github',
       official_status = 'unverified',
       hosting_provider = 'none',
       runtime_profile = 'local-web-wasm',
       repository_owner = CASE
         WHEN json_extract(source_identity_json, '$.repository') LIKE '%/%'
         THEN substr(
           json_extract(source_identity_json, '$.repository'),
           1,
           instr(json_extract(source_identity_json, '$.repository'), '/') - 1
         )
         ELSE repository_owner
       END,
       repository_name = CASE
         WHEN json_extract(source_identity_json, '$.repository') LIKE '%/%'
         THEN substr(
           json_extract(source_identity_json, '$.repository'),
           instr(json_extract(source_identity_json, '$.repository'), '/') + 1
         )
         ELSE repository_name
       END,
       repository_id = COALESCE(
         CAST(json_extract(source_identity_json, '$.repositoryId') AS INTEGER),
         repository_id
       )
 WHERE json_extract(source_identity_json, '$.provider') = 'github'
    OR json_extract(source_identity_json, '$.repository') LIKE '%/%';

CREATE TABLE IF NOT EXISTS miniapp_projects (
  local_project_id TEXT PRIMARY KEY,
  plugin_id TEXT NOT NULL UNIQUE,
  owner_user_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  workspace_source_tree_hash TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS miniapp_deployments (
  deployment_id TEXT PRIMARY KEY,
  local_project_id TEXT NOT NULL REFERENCES miniapp_projects(local_project_id) ON DELETE RESTRICT,
  author TEXT NOT NULL,
  source_host TEXT NOT NULL CHECK (source_host IN ('local','github')),
  source_custody TEXT NOT NULL CHECK (source_custody IN ('device','platform-managed','user-owned')),
  source_provider TEXT NOT NULL CHECK (source_provider IN ('local','github')),
  source_actor TEXT NOT NULL CHECK (source_actor IN ('user','platform')),
  source_transport TEXT NOT NULL CHECK (source_transport IN ('local-fs','github-mcp','github-app-api')),
  repository_owner TEXT,
  repository_name TEXT,
  repository_id INTEGER,
  publisher TEXT NOT NULL,
  official_status TEXT NOT NULL CHECK (official_status IN ('official','community','unverified')),
  hosting_provider TEXT NOT NULL DEFAULT 'none'
    CHECK (hosting_provider IN ('none','github-pages','cloudflare-pages','cloudflare-workers','external')),
  runtime_profile TEXT NOT NULL DEFAULT 'local-web-wasm'
    CHECK (runtime_profile IN ('local-native','local-web-wasm','web-static','remote-edge')),
  deployment_target TEXT NOT NULL
    CHECK (deployment_target IN ('local-only','official-managed-github','user-github','official-source-github')),
  default_branch TEXT,
  source_commit TEXT,
  source_tree_hash TEXT NOT NULL,
  workspace_state TEXT NOT NULL DEFAULT 'local-ready'
    CHECK (workspace_state IN ('local-ready','dirty','snapshotting','snapshot-ready','conflict')),
  source_state TEXT NOT NULL DEFAULT 'none'
    CHECK (source_state IN ('none','consented','syncing','hosted','diverged','failed','outcome-unknown')),
  build_state TEXT NOT NULL DEFAULT 'none'
    CHECK (build_state IN ('none','queued','validating','passed','failed')),
  hosting_state TEXT NOT NULL DEFAULT 'none'
    CHECK (hosting_state IN ('none','queued','deploying','deployed','failed','rolled-back')),
  market_state TEXT NOT NULL DEFAULT 'none'
    CHECK (market_state IN ('none','review','listed','installable','suspended','revoked')),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  CHECK (
    (deployment_target = 'local-only'
      AND source_host = 'local'
      AND source_custody = 'device'
      AND source_provider = 'local'
      AND source_actor = 'user'
      AND source_transport = 'local-fs'
      AND repository_owner IS NULL
      AND repository_name IS NULL
      AND repository_id IS NULL
      AND source_commit IS NULL)
    OR
    (deployment_target <> 'local-only'
      AND source_host = 'github'
      AND source_provider = 'github'
      AND repository_owner IS NOT NULL
      AND repository_name IS NOT NULL
      AND repository_id IS NOT NULL
      AND repository_id > 0
      AND source_commit IS NOT NULL
      AND default_branch IS NOT NULL
      AND source_transport IN ('github-mcp','github-app-api'))
  ),
  CHECK (
    (hosting_provider IN ('github-pages','cloudflare-pages') AND runtime_profile = 'web-static')
    OR (hosting_provider = 'cloudflare-workers' AND runtime_profile = 'remote-edge')
    OR hosting_provider IN ('none','external')
  )
);

CREATE INDEX IF NOT EXISTS miniapp_deployments_project_idx
  ON miniapp_deployments(local_project_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS miniapp_deployments_repository_idx
  ON miniapp_deployments(repository_id, source_commit);
