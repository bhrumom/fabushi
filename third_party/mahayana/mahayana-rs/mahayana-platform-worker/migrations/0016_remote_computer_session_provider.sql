-- RDF-002: bind every control session to the provider declared by the registered device.
-- This remains additive: existing fabushi-webrtc sessions keep working, while a future
-- rustdesk-sidecar transport can share the same Fabushi identity/authorization/session rows.
ALTER TABLE remote_computer_sessions
    ADD COLUMN provider TEXT NOT NULL DEFAULT 'fabushi-webrtc'
    CHECK (provider IN ('fabushi-webrtc', 'rustdesk-sidecar'));

-- Backfill from the authoritative account-scoped device inventory instead of trusting
-- the historical default.
UPDATE remote_computer_sessions
SET provider = COALESCE(
    (SELECT computer.provider
     FROM remote_computers AS computer
     WHERE computer.device_id = remote_computer_sessions.device_id
       AND computer.user_id = remote_computer_sessions.user_id),
    'fabushi-webrtc'
);

-- Existing Worker code does not yet pass a provider in INSERT. Bind it atomically after
-- insertion from the registered computer so the session never derives provider choice
-- from an untrusted mobile client.
CREATE TRIGGER IF NOT EXISTS remote_computer_session_provider_bind_after_insert
AFTER INSERT ON remote_computer_sessions
FOR EACH ROW
BEGIN
    UPDATE remote_computer_sessions
    SET provider = COALESCE(
        (SELECT computer.provider
         FROM remote_computers AS computer
         WHERE computer.device_id = NEW.device_id
           AND computer.user_id = NEW.user_id),
        'fabushi-webrtc'
    )
    WHERE session_id = NEW.session_id;
END;

-- A session's transport provider is immutable and must continue to match its registered
-- device. Provider changes require a new session, which preserves auditability.
CREATE TRIGGER IF NOT EXISTS remote_computer_session_provider_immutable
BEFORE UPDATE OF provider ON remote_computer_sessions
FOR EACH ROW
WHEN NEW.provider <> OLD.provider
BEGIN
    SELECT RAISE(ABORT, 'remote session provider is immutable');
END;

CREATE INDEX IF NOT EXISTS remote_computer_sessions_provider_idx
    ON remote_computer_sessions(user_id, device_id, provider, state, expires_at);
