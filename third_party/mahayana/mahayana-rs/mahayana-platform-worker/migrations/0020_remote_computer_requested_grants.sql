-- RDF-005/RDF-006: persist the exact immutable capability request on the session
-- before the default grant/audit trigger runs. Existing sessions retain the
-- historical display+input / no-extended-capability defaults.
ALTER TABLE remote_computer_sessions ADD COLUMN allow_display INTEGER NOT NULL DEFAULT 1 CHECK (allow_display IN (0, 1));
ALTER TABLE remote_computer_sessions ADD COLUMN allow_input INTEGER NOT NULL DEFAULT 1 CHECK (allow_input IN (0, 1));
ALTER TABLE remote_computer_sessions ADD COLUMN allow_clipboard INTEGER NOT NULL DEFAULT 0 CHECK (allow_clipboard IN (0, 1));
ALTER TABLE remote_computer_sessions ADD COLUMN allow_file_transfer INTEGER NOT NULL DEFAULT 0 CHECK (allow_file_transfer IN (0, 1));
ALTER TABLE remote_computer_sessions ADD COLUMN allow_audio INTEGER NOT NULL DEFAULT 0 CHECK (allow_audio IN (0, 1));

DROP TRIGGER IF EXISTS remote_computer_session_default_grant;
CREATE TRIGGER remote_computer_session_default_grant
AFTER INSERT ON remote_computer_sessions
FOR EACH ROW
BEGIN
    INSERT INTO remote_computer_session_grants
      (session_id,user_id,device_id,client_id,allow_display,allow_input,allow_clipboard,allow_file_transfer,allow_audio,granted_at,expires_at,revoked_at)
    VALUES (NEW.session_id,NEW.user_id,NEW.device_id,NEW.client_id,
            NEW.allow_display,NEW.allow_input,NEW.allow_clipboard,NEW.allow_file_transfer,NEW.allow_audio,
            NEW.created_at,NEW.expires_at,NULL);
    INSERT INTO remote_computer_audit_events
      (user_id,device_id,client_id,session_id,event_type,provider,route,created_at)
    VALUES (NEW.user_id,NEW.device_id,NEW.client_id,NEW.session_id,'session-created',NEW.provider,NULL,NEW.created_at);
END;
