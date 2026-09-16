-- Marketplace security admission state.
-- Existing official rows are explicitly marked with a compatibility baseline so
-- this migration does not silently remove already-public first-party releases.
-- Every newly submitted release is explicitly inserted as pending by the
-- publish handlers and must receive a signed all-pass result before promotion.

ALTER TABLE plugin_releases
ADD COLUMN security_scan_status TEXT NOT NULL DEFAULT 'pending';

ALTER TABLE plugin_releases
ADD COLUMN security_scan_json TEXT NOT NULL DEFAULT '{}';

ALTER TABLE plugin_releases
ADD COLUMN security_scanned_at INTEGER;

ALTER TABLE plugin_releases
ADD COLUMN security_next_scan_at INTEGER;

ALTER TABLE plugin_releases
ADD COLUMN security_scan_started_at INTEGER;

ALTER TABLE plugin_releases
ADD COLUMN security_scan_run_id TEXT NOT NULL DEFAULT '';

ALTER TABLE plugin_releases
ADD COLUMN security_signature_json TEXT NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS plugin_releases_security_queue_idx
    ON plugin_releases(security_scan_status, security_next_scan_at, release_status);

-- Make the compatibility status explicit for the pre-gate official catalog.
-- These rows are intentionally marked as legacy in the stored report and must
-- be replaced by a signed baseline scan before their next security-sensitive
-- release migration.
UPDATE plugin_releases
SET security_scan_status = 'passed',
    security_scan_json = '{"schemaVersion":1,"status":"passed","mode":"legacy-official-baseline","checks":{"malware":"grandfathered","dynamicSandbox":"grandfathered","secrets":"grandfathered","dependencies":"grandfathered"}}',
    security_scanned_at = CAST(strftime('%s', 'now') AS INTEGER),
    security_next_scan_at = CAST(strftime('%s', 'now') AS INTEGER) + 86400
WHERE security_scan_json = '{}'
  AND release_status = 'approved';
