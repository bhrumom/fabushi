const REMOTE_PAIRING_SECONDS: i64 = 10 * 60;
const REMOTE_CONTROL_SESSION_SECONDS: i64 = 2 * 60 * 60;
const REMOTE_SIGNAL_SECONDS: i64 = 5 * 60;
const REMOTE_SIGNAL_MAX_BYTES: usize = 256 * 1024;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct RemoteComputerRegisterRequest {
    device_id: String,
    label: String,
    device_secret: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct RemoteComputerHeartbeatRequest {
    device_id: String,
    device_secret: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct RemoteComputerPairRequest {
    pairing_code: String,
    label: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct RemoteComputerSessionCreateRequest {
    client_id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct RemoteComputerDesktopAuthRequest {
    device_secret: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct RemoteComputerSignalRequest {
    session_id: String,
    sender_role: String,
    #[serde(default)]
    device_secret: Option<String>,
    #[serde(default)]
    client_id: Option<String>,
    #[serde(default)]
    mobile_token: Option<String>,
    kind: String,
    payload: Value,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct RemoteComputerSignalDrainRequest {
    session_id: String,
    receiver_role: String,
    #[serde(default)]
    device_secret: Option<String>,
    #[serde(default)]
    client_id: Option<String>,
    #[serde(default)]
    mobile_token: Option<String>,
    #[serde(default)]
    after_signal_id: Option<i64>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct RemoteComputerSessionCloseRequest {
    role: String,
    #[serde(default)]
    device_secret: Option<String>,
    #[serde(default)]
    client_id: Option<String>,
    #[serde(default)]
    mobile_token: Option<String>,
}

#[derive(Debug, Deserialize)]
struct RemoteComputerRow {
    device_id: String,
    label: String,
    last_seen_at: i64,
    created_at: i64,
}

#[derive(Debug, Deserialize)]
struct RemoteComputerPairRow {
    device_id: String,
    label: String,
}

#[derive(Debug, Deserialize)]
struct RemoteComputerExistsRow {
    ok: i64,
}

#[derive(Debug, Deserialize)]
struct RemoteComputerSecretRow {
    device_secret_hash: String,
}

#[derive(Debug, Deserialize)]
struct RemoteComputerClientRow {
    client_id: String,
    label: String,
    paired_at: i64,
    last_seen_at: i64,
}

#[derive(Debug, Deserialize)]
struct RemoteComputerSessionRow {
    client_id: String,
    mobile_token_hash: String,
    state: String,
    expires_at: i64,
}

#[derive(Debug, Deserialize)]
struct RemoteComputerSessionListRow {
    session_id: String,
    client_id: String,
    client_label: String,
    state: String,
    created_at: i64,
    expires_at: i64,
}

#[derive(Debug, Deserialize)]
struct RemoteComputerSignalRow {
    signal_id: i64,
    sender_role: String,
    kind: String,
    payload_json: String,
    created_at: i64,
}
