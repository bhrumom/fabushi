ALTER TABLE marketplace_plugins ADD COLUMN production_version TEXT;
ALTER TABLE marketplace_plugins ADD COLUMN migration_state TEXT NOT NULL DEFAULT 'ready'
  CHECK (migration_state IN ('ready','migration_required','blocked'));

ALTER TABLE plugin_releases ADD COLUMN metadata_version INTEGER NOT NULL DEFAULT 3;

CREATE TABLE IF NOT EXISTS plugin_release_artifacts (
  plugin_id TEXT NOT NULL,
  version TEXT NOT NULL,
  artifact_id TEXT NOT NULL,
  artifact_kind TEXT NOT NULL CHECK (artifact_kind IN ('common','native-cli','web-wasm')),
  platform_json TEXT NOT NULL,
  source_commit TEXT NOT NULL,
  artifact_url TEXT NOT NULL,
  artifact_sha256 TEXT NOT NULL,
  artifact_size INTEGER NOT NULL CHECK (artifact_size > 0),
  media_type TEXT NOT NULL,
  sbom_url TEXT NOT NULL,
  attestation_url TEXT NOT NULL,
  min_host_version TEXT NOT NULL,
  required_capabilities_json TEXT NOT NULL DEFAULT '[]',
  created_at INTEGER NOT NULL,
  PRIMARY KEY(plugin_id, version, artifact_id)
);

CREATE INDEX IF NOT EXISTS plugin_release_artifacts_source_idx
  ON plugin_release_artifacts(plugin_id, version, source_commit);
