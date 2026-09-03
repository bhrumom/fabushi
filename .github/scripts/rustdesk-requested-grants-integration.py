from pathlib import Path

worker_path = Path('third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs')
worker = worker_path.read_text()

old_create = '''struct RemoteComputerSessionCreateRequest {
    client_id: String,
    client_token: String,
}
'''
new_create = '''struct RemoteComputerSessionCreateRequest {
    client_id: String,
    client_token: String,
    #[serde(default = "default_remote_control_permissions")]
    permissions: RemoteComputerPermissionsRequest,
}

#[derive(Debug, Clone, Copy, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct RemoteComputerPermissionsRequest {
    display: bool,
    input: bool,
    clipboard: bool,
    file_transfer: bool,
    audio: bool,
}

fn default_remote_control_permissions() -> RemoteComputerPermissionsRequest {
    RemoteComputerPermissionsRequest {
        display: true,
        input: true,
        clipboard: false,
        file_transfer: false,
        audio: false,
    }
}
'''
if old_create in worker:
    worker = worker.replace(old_create, new_create, 1)
elif new_create not in worker:
    raise SystemExit('session-create request marker changed')

old_row = '''struct RemoteComputerSessionListRow {
    session_id: String,
    client_id: String,
    client_label: String,
    state: String,
    created_at: i64,
    expires_at: i64,
}
'''
new_row = '''struct RemoteComputerSessionListRow {
    session_id: String,
    client_id: String,
    client_label: String,
    state: String,
    created_at: i64,
    expires_at: i64,
    allow_display: i64,
    allow_input: i64,
    allow_clipboard: i64,
    allow_file_transfer: i64,
    allow_audio: i64,
}
'''
if old_row in worker:
    worker = worker.replace(old_row, new_row, 1)
elif new_row not in worker:
    raise SystemExit('session-list row marker changed')

old_list_query = '''        "SELECT s.session_id, s.client_id, c.label AS client_label,
                s.state, s.created_at, s.expires_at
         FROM remote_computer_sessions s
         JOIN remote_computer_clients c
           ON c.client_id = s.client_id AND c.device_id = s.device_id AND c.user_id = s.user_id
         JOIN remote_computers d ON d.device_id = s.device_id AND d.user_id = s.user_id
         WHERE s.user_id = ?1 AND s.device_id = ?2 AND s.state <> 'closed'
           AND s.expires_at > ?3 AND c.revoked_at IS NULL
           AND c.client_token_hash IS NOT NULL AND d.revoked_at IS NULL
         ORDER BY s.created_at DESC LIMIT 32",
'''
new_list_query = '''        "SELECT s.session_id, s.client_id, c.label AS client_label,
                s.state, s.created_at, s.expires_at,
                g.allow_display, g.allow_input, g.allow_clipboard,
                g.allow_file_transfer, g.allow_audio
         FROM remote_computer_sessions s
         JOIN remote_computer_clients c
           ON c.client_id = s.client_id AND c.device_id = s.device_id AND c.user_id = s.user_id
         JOIN remote_computers d ON d.device_id = s.device_id AND d.user_id = s.user_id
         JOIN remote_computer_session_grants g
           ON g.session_id = s.session_id AND g.user_id = s.user_id
          AND g.device_id = s.device_id AND g.client_id = s.client_id
         WHERE s.user_id = ?1 AND s.device_id = ?2 AND s.state <> 'closed'
           AND s.expires_at > ?3 AND c.revoked_at IS NULL
           AND c.client_token_hash IS NOT NULL AND d.revoked_at IS NULL
           AND g.revoked_at IS NULL AND g.expires_at > ?3
         ORDER BY s.created_at DESC LIMIT 32",
'''
if old_list_query in worker:
    worker = worker.replace(old_list_query, new_list_query, 1)
elif new_list_query not in worker:
    raise SystemExit('session-list query marker changed')

old_list_permissions = '''                "permissions": {"display": true, "input": true, "clipboard": false, "fileTransfer": false, "audio": false},
'''
new_list_permissions = '''                "permissions": {
                    "display": row.allow_display != 0,
                    "input": row.allow_input != 0,
                    "clipboard": row.allow_clipboard != 0,
                    "fileTransfer": row.allow_file_transfer != 0,
                    "audio": row.allow_audio != 0,
                },
'''
if old_list_permissions in worker:
    worker = worker.replace(old_list_permissions, new_list_permissions, 1)
elif new_list_permissions not in worker:
    raise SystemExit('session-list permissions marker changed')

validation_marker = '''    if input.client_token.len() < 48 || input.client_token.len() > 256 {
        return error_response(
            400,
            "invalid_client_token",
            "Paired client credential is invalid.",
        );
    }
'''
validation_new = validation_marker + '''    if !input.permissions.display {
        return error_response(
            400,
            "display_permission_required",
            "Remote control sessions must explicitly grant display access.",
        );
    }
'''
if 'display_permission_required' not in worker:
    if validation_marker not in worker:
        raise SystemExit('session-create validation marker changed')
    worker = worker.replace(validation_marker, validation_new, 1)

old_insert = '''        "INSERT INTO remote_computer_sessions
         (session_id, device_id, client_id, user_id, mobile_token_hash, state, created_at, expires_at, closed_at)
         SELECT ?1, ?2, ?3, ?4, ?5, 'pending', ?6, ?7, NULL
         WHERE EXISTS (
                 SELECT 1 FROM remote_computer_clients c
                 JOIN remote_computers d
                   ON d.device_id = c.device_id AND d.user_id = c.user_id
                 WHERE c.client_id = ?3 AND c.device_id = ?2 AND c.user_id = ?4
                   AND c.client_token_hash = ?10 AND c.revoked_at IS NULL
                   AND d.revoked_at IS NULL
               )
           AND (SELECT COUNT(*) FROM remote_computer_sessions
                WHERE user_id = ?4 AND device_id = ?2 AND client_id = ?3
                  AND state <> 'closed' AND expires_at > ?6) < ?8
           AND (SELECT COUNT(*) FROM remote_computer_sessions
                WHERE user_id = ?4 AND device_id = ?2
                  AND state <> 'closed' AND expires_at > ?6) < ?9",
        &session_id,
        &device_id,
        &input.client_id,
        &account.user_id,
        &mobile_token_hash,
        now,
        expires_at,
        REMOTE_SESSION_MAX_PER_CLIENT,
        REMOTE_SESSION_MAX_PER_DEVICE,
        &candidate_hash
'''
new_insert = '''        "INSERT INTO remote_computer_sessions
         (session_id, device_id, client_id, user_id, mobile_token_hash, state, created_at, expires_at, closed_at,
          allow_display, allow_input, allow_clipboard, allow_file_transfer, allow_audio)
         SELECT ?1, ?2, ?3, ?4, ?5, 'pending', ?6, ?7, NULL, ?8, ?9, ?10, ?11, ?12
         WHERE EXISTS (
                 SELECT 1 FROM remote_computer_clients c
                 JOIN remote_computers d
                   ON d.device_id = c.device_id AND d.user_id = c.user_id
                 WHERE c.client_id = ?3 AND c.device_id = ?2 AND c.user_id = ?4
                   AND c.client_token_hash = ?15 AND c.revoked_at IS NULL
                   AND d.revoked_at IS NULL
               )
           AND (SELECT COUNT(*) FROM remote_computer_sessions
                WHERE user_id = ?4 AND device_id = ?2 AND client_id = ?3
                  AND state <> 'closed' AND expires_at > ?6) < ?13
           AND (SELECT COUNT(*) FROM remote_computer_sessions
                WHERE user_id = ?4 AND device_id = ?2
                  AND state <> 'closed' AND expires_at > ?6) < ?14",
        &session_id,
        &device_id,
        &input.client_id,
        &account.user_id,
        &mobile_token_hash,
        now,
        expires_at,
        input.permissions.display as i64,
        input.permissions.input as i64,
        input.permissions.clipboard as i64,
        input.permissions.file_transfer as i64,
        input.permissions.audio as i64,
        REMOTE_SESSION_MAX_PER_CLIENT,
        REMOTE_SESSION_MAX_PER_DEVICE,
        &candidate_hash
'''
if old_insert in worker:
    worker = worker.replace(old_insert, new_insert, 1)
elif new_insert not in worker:
    raise SystemExit('session insert marker changed')

old_response_permissions = '''        "permissions": {"display": true, "input": true, "clipboard": false, "fileTransfer": false, "audio": false},
'''
new_response_permissions = '''        "permissions": {
            "display": input.permissions.display,
            "input": input.permissions.input,
            "clipboard": input.permissions.clipboard,
            "fileTransfer": input.permissions.file_transfer,
            "audio": input.permissions.audio,
        },
'''
if old_response_permissions in worker:
    worker = worker.replace(old_response_permissions, new_response_permissions, 1)
elif new_response_permissions not in worker:
    raise SystemExit('session-create response permissions marker changed')

worker_path.write_text(worker)

api_path = Path('frontend/apps/web/src/lib/remote-computer/remote-api.ts')
api = api_path.read_text()
old_signature = '''  async createControlSession(deviceId: string, clientId: string, clientToken: string): Promise<MobileControlSession> {
'''
new_signature = '''  async createControlSession(
    deviceId: string,
    clientId: string,
    clientToken: string,
    permissions: RemoteControlPermissions = { display: true, input: true, clipboard: false, fileTransfer: false, audio: false },
  ): Promise<MobileControlSession> {
'''
if old_signature in api:
    api = api.replace(old_signature, new_signature, 1)
elif new_signature not in api:
    raise SystemExit('remote-api createControlSession signature marker changed')

old_body = '''      body: JSON.stringify({ clientId, clientToken }),
'''
new_body = '''      body: JSON.stringify({ clientId, clientToken, permissions }),
'''
if old_body in api:
    api = api.replace(old_body, new_body, 1)
elif new_body not in api:
    raise SystemExit('remote-api request body marker changed')

validation = '''    if (!permissions || permissions.display !== true
      || [permissions.input, permissions.clipboard, permissions.fileTransfer, permissions.audio].some((value) => typeof value !== "boolean")) {
      throw new Error("远程控制权限请求无效");
    }
'''
credential_marker = '''      throw new Error("本手机的配对凭据无效，请重新配对");
    }
'''
if '远程控制权限请求无效' not in api:
    if credential_marker not in api:
        raise SystemExit('remote-api credential validation marker changed')
    api = api.replace(credential_marker, credential_marker + validation, 1)
api_path.write_text(api)

test_path = Path('chatgpt-vps-control/tests/rustdesk-session-permission-enforcement.test.js')
tests = test_path.read_text()
old_default_test = '''test("session grant defaults are returned to desktop and mobile clients", () => {
  const worker = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs");
  assert.match(worker, /"permissions": \\{"display": true, "input": true, "clipboard": false, "fileTransfer": false, "audio": false\\}/);
  const api = source("frontend/apps/web/src/lib/remote-computer/remote-api.ts");
  assert.match(api, /normalizeRemoteControlPermissions/);
  assert.match(api, /permissions: normalizeRemoteControlPermissions\\(raw\\.permissions\\)!/);
});
'''
new_default_test = '''test("session grant defaults remain least privilege while responses use authoritative persisted grants", () => {
  const worker = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs");
  assert.match(worker, /fn default_remote_control_permissions/);
  assert.match(worker, /display: true/);
  assert.match(worker, /input: true/);
  assert.match(worker, /clipboard: false/);
  assert.match(worker, /file_transfer: false/);
  assert.match(worker, /audio: false/);
  assert.match(worker, /JOIN remote_computer_session_grants g/);
  assert.match(worker, /"clipboard": row\\.allow_clipboard != 0/);
  const api = source("frontend/apps/web/src/lib/remote-computer/remote-api.ts");
  assert.match(api, /normalizeRemoteControlPermissions/);
  assert.match(api, /permissions: normalizeRemoteControlPermissions\\(raw\\.permissions\\)!/);
});
'''
if old_default_test in tests:
    tests = tests.replace(old_default_test, new_default_test, 1)
elif new_default_test not in tests:
    raise SystemExit('session grant default contract marker changed')
addition = '''\ntest("requested provider grants are persisted before activation and cannot be widened in place", () => {
  const worker = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs");
  const migration = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0020_remote_computer_requested_grants.sql");
  const api = source("frontend/apps/web/src/lib/remote-computer/remote-api.ts");
  assert.match(worker, /permissions: RemoteComputerPermissionsRequest/);
  assert.match(worker, /input\\.permissions\\.clipboard as i64/);
  assert.match(worker, /JOIN remote_computer_session_grants g/);
  assert.match(worker, /row\\.allow_file_transfer != 0/);
  assert.match(migration, /NEW\\.allow_clipboard/);
  assert.match(migration, /NEW\\.allow_file_transfer/);
  assert.match(migration, /NEW\\.allow_audio/);
  assert.match(api, /JSON\\.stringify\\(\\{ clientId, clientToken, permissions \\}\\)/);
});
'''
if 'requested provider grants are persisted before activation' not in tests:
    tests += addition
test_path.write_text(tests)
