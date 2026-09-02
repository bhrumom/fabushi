from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"{label} marker changed")
    return text.replace(old, new, 1)


worker = Path("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs")
text = worker.read_text(encoding="utf-8")

text = replace_once(
    text,
    '''struct RemoteComputerSessionCreateRequest {
    client_id: String,
    client_token: String,
}
''',
    '''struct RemoteComputerSessionCreateRequest {
    client_id: String,
    client_token: String,
    #[serde(default)]
    permissions: RemoteComputerRequestedPermissions,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct RemoteComputerRequestedPermissions {
    display: bool,
    input: bool,
    clipboard: bool,
    file_transfer: bool,
    audio: bool,
}

impl Default for RemoteComputerRequestedPermissions {
    fn default() -> Self {
        Self {
            display: true,
            input: true,
            clipboard: false,
            file_transfer: false,
            audio: false,
        }
    }
}
''',
    "requested permissions request",
)

text = replace_once(
    text,
    '''struct RemoteComputerSessionListRow {
    session_id: String,
    client_id: String,
    client_label: String,
    state: String,
    created_at: i64,
    expires_at: i64,
}
''',
    '''struct RemoteComputerSessionListRow {
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
''',
    "session list permission columns",
)

text = replace_once(
    text,
    '''        "SELECT s.session_id, s.client_id, c.label AS client_label,
                s.state, s.created_at, s.expires_at
''',
    '''        "SELECT s.session_id, s.client_id, c.label AS client_label,
                s.state, s.created_at, s.expires_at,
                s.allow_display, s.allow_input, s.allow_clipboard,
                s.allow_file_transfer, s.allow_audio
''',
    "session list permission select",
)

text = replace_once(
    text,
    '''                "permissions": {"display": true, "input": true, "clipboard": false, "fileTransfer": false, "audio": false},
''',
    '''                "permissions": {
                    "display": row.allow_display != 0,
                    "input": row.allow_input != 0,
                    "clipboard": row.allow_clipboard != 0,
                    "fileTransfer": row.allow_file_transfer != 0,
                    "audio": row.allow_audio != 0,
                },
''',
    "session list exact permissions",
)

text = replace_once(
    text,
    '''    if input.client_token.len() < 48 || input.client_token.len() > 256 {
        return error_response(
            400,
            "invalid_client_token",
            "Paired client credential is invalid.",
        );
    }
''',
    '''    if input.client_token.len() < 48 || input.client_token.len() > 256 {
        return error_response(
            400,
            "invalid_client_token",
            "Paired client credential is invalid.",
        );
    }
    if !input.permissions.display {
        return error_response(
            400,
            "display_permission_required",
            "Remote control sessions require display permission.",
        );
    }
''',
    "display grant required",
)

text = replace_once(
    text,
    '''        "INSERT INTO remote_computer_sessions
         (session_id, device_id, client_id, user_id, mobile_token_hash, state, created_at, expires_at, closed_at)
         SELECT ?1, ?2, ?3, ?4, ?5, 'pending', ?6, ?7, NULL
''',
    '''        "INSERT INTO remote_computer_sessions
         (session_id, device_id, client_id, user_id, mobile_token_hash, state, created_at, expires_at, closed_at,
          allow_display, allow_input, allow_clipboard, allow_file_transfer, allow_audio)
         SELECT ?1, ?2, ?3, ?4, ?5, 'pending', ?6, ?7, NULL, ?11, ?12, ?13, ?14, ?15
''',
    "persist requested grants",
)

text = replace_once(
    text,
    '''        &candidate_hash
    )?
''',
    '''        &candidate_hash,
        i64::from(input.permissions.display),
        i64::from(input.permissions.input),
        i64::from(input.permissions.clipboard),
        i64::from(input.permissions.file_transfer),
        i64::from(input.permissions.audio)
    )?
''',
    "bind requested grants",
)

text = replace_once(
    text,
    '''        "permissions": {"display": true, "input": true, "clipboard": false, "fileTransfer": false, "audio": false},
        "iceServers": remote_ice_servers(&context.env),
''',
    '''        "permissions": {
            "display": input.permissions.display,
            "input": input.permissions.input,
            "clipboard": input.permissions.clipboard,
            "fileTransfer": input.permissions.file_transfer,
            "audio": input.permissions.audio,
        },
        "iceServers": remote_ice_servers(&context.env),
''',
    "create response exact permissions",
)

worker.write_text(text, encoding="utf-8")

lib = Path("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/lib.rs")
text = lib.read_text(encoding="utf-8")
text = replace_once(
    text,
    '''pub const REMOTE_COMPUTER_AUDIT_GRANTS_SCHEMA_V19: &str =
    include_str!("../migrations/0019_remote_computer_audit_grants.sql");
''',
    '''pub const REMOTE_COMPUTER_AUDIT_GRANTS_SCHEMA_V19: &str =
    include_str!("../migrations/0019_remote_computer_audit_grants.sql");
pub const REMOTE_COMPUTER_REQUESTED_GRANTS_SCHEMA_V20: &str =
    include_str!("../migrations/0020_remote_computer_requested_grants.sql");
''',
    "migration 0020 registry",
)
lib.write_text(text, encoding="utf-8")

api = Path("frontend/apps/web/src/lib/remote-computer/remote-api.ts")
text = api.read_text(encoding="utf-8")
text = replace_once(
    text,
    '''  async createControlSession(deviceId: string, clientId: string, clientToken: string): Promise<MobileControlSession> {
    if (!validStoredIdentifier(deviceId, 128)
      || !validStoredIdentifier(clientId)
      || !validOpaqueCredential(clientToken)) {
      throw new Error("本手机的配对凭据无效，请重新配对");
    }
    const response = await this.authorizedFetch(`/v1/computers/${encodeURIComponent(deviceId)}/sessions`, {
      method: "POST",
      body: JSON.stringify({ clientId, clientToken }),
    });
''',
    '''  async createControlSession(
    deviceId: string,
    clientId: string,
    clientToken: string,
    requestedPermissions: RemoteControlPermissions = {
      display: true,
      input: true,
      clipboard: false,
      fileTransfer: false,
      audio: false,
    },
  ): Promise<MobileControlSession> {
    if (!validStoredIdentifier(deviceId, 128)
      || !validStoredIdentifier(clientId)
      || !validOpaqueCredential(clientToken)) {
      throw new Error("本手机的配对凭据无效，请重新配对");
    }
    const permissions = normalizeRemoteControlPermissions(requestedPermissions);
    if (!permissions || permissions.display !== true) {
      throw new Error("远程控制会话必须明确授权屏幕显示");
    }
    const response = await this.authorizedFetch(`/v1/computers/${encodeURIComponent(deviceId)}/sessions`, {
      method: "POST",
      body: JSON.stringify({ clientId, clientToken, permissions }),
    });
''',
    "mobile requested permissions",
)
api.write_text(text, encoding="utf-8")
