// SPDX-License-Identifier: AGPL-3.0-only
// Fabushi RustDesk sidecar overlay. This file is intentionally distributed
// separately from Fabushi core and is compiled only inside the pinned RustDesk
// source tree recorded in integrations/rustdesk-sidecar/UPSTREAM.lock.

use hbb_common::{message_proto::*, rendezvous_proto::ConnType};
use librustdesk::{
    client::{Data, FileManager, Interface, QualityStatus},
    ui_session_interface::{InvokeUiSession, Session},
};
use serde::Deserialize;
use serde_json::{json, Value};
use std::{
    collections::HashMap,
    io::{self, BufRead, Write},
    sync::{atomic::AtomicUsize, Arc, Mutex, RwLock},
};

const PROTOCOL: &str = "fabushi.rustdesk-sidecar.v1";
const MAX_LINE_BYTES: usize = 1024 * 1024;
const MAX_CLIPBOARD_BYTES: usize = 512 * 1024;
const MAX_PATH_BYTES: usize = 4096;
const FRAME_CHUNK_BYTES: usize = 256 * 1024;
const MAX_FRAME_BYTES: usize = 64 * 1024 * 1024;

lazy_static::lazy_static! {
    static ref STDOUT_LOCK: Mutex<()> = Mutex::new(());
    static ref SESSIONS: Mutex<HashMap<String, SidecarSession>> = Mutex::new(HashMap::new());
}

#[derive(Debug, Clone, Copy, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Grant {
    display: bool,
    input: bool,
    clipboard: bool,
    file_transfer: bool,
    audio: bool,
}

#[derive(Clone)]
struct SidecarSession {
    session: Session<BridgeHandler>,
    grant: Grant,
    audio_baseline_disabled: bool,
}

#[derive(Clone, Default)]
struct BridgeHandler {
    session_id: String,
    display_size: Arc<RwLock<(i32, i32)>>,
}

fn emit(value: Value) {
    let _guard = STDOUT_LOCK.lock().unwrap();
    let mut stdout = io::stdout().lock();
    let _ = serde_json::to_writer(&mut stdout, &value);
    let _ = stdout.write_all(b"\n");
    let _ = stdout.flush();
}

impl BridgeHandler {
    fn event(&self, kind: &str, detail: Value) {
        emit(json!({
            "protocol": PROTOCOL,
            "type": kind,
            "sessionId": self.session_id,
            "detail": detail,
        }));
    }
}

impl InvokeUiSession for BridgeHandler {
    fn set_cursor_data(&self, cd: CursorData) {
        self.event("cursorData", json!({"id": cd.id, "hotX": cd.hotx, "hotY": cd.hoty, "width": cd.width, "height": cd.height}));
    }
    fn set_cursor_id(&self, id: String) { self.event("cursor", json!({"id": id})); }
    fn set_cursor_position(&self, cp: CursorPosition) { self.event("cursorPosition", json!({"x": cp.x, "y": cp.y})); }
    fn set_display(&self, x: i32, y: i32, w: i32, h: i32, cursor_embedded: bool, scale: f64) {
        *self.display_size.write().unwrap() = (w, h);
        self.event("display", json!({"x": x, "y": y, "width": w, "height": h, "cursorEmbedded": cursor_embedded, "scale": scale}));
    }
    fn switch_display(&self, display: &SwitchDisplay) { self.event("displayChanged", json!({"display": display.display, "width": display.width, "height": display.height})); }
    fn set_peer_info(&self, peer_info: &PeerInfo) {
        self.event("peer", json!({"username": peer_info.username, "hostname": peer_info.hostname, "platform": peer_info.platform, "version": peer_info.version}));
    }
    fn set_displays(&self, displays: &Vec<DisplayInfo>) { self.event("displays", json!({"count": displays.len()})); }
    fn set_platform_additions(&self, _data: &str) {}
    fn on_connected(&self, conn_type: ConnType) { self.event("ready", json!({"connectionType": format!("{:?}", conn_type)})); }
    fn update_privacy_mode(&self) {}
    fn set_permission(&self, name: &str, value: bool) { self.event("peerPermission", json!({"name": name, "value": value})); }
    fn close_success(&self) { self.event("closeSuccess", json!({})); }
    fn update_quality_status(&self, qs: QualityStatus) {
        self.event("quality", json!({"speed": qs.speed, "delay": qs.delay, "targetBitrate": qs.target_bitrate}));
    }
    fn set_connection_type(&self, is_secured: bool, direct: bool, stream_type: &str) {
        self.event("route", json!({"secure": is_secured, "direct": direct, "streamType": stream_type}));
    }
    fn set_fingerprint(&self, fingerprint: String) { self.event("fingerprint", json!({"fingerprint": fingerprint})); }
    fn job_error(&self, id: i32, err: String, file_num: i32) { self.event("fileError", json!({"jobId": id, "file": file_num, "error": err})); }
    fn job_done(&self, id: i32, file_num: i32) { self.event("fileDone", json!({"jobId": id, "file": file_num})); }
    fn clear_all_jobs(&self) { self.event("fileJobsCleared", json!({})); }
    fn new_message(&self, msg: String) { self.event("message", json!({"message": msg})); }
    fn update_transfer_list(&self) { self.event("fileTransferListChanged", json!({})); }
    fn load_last_job(&self, cnt: i32, _job_json: &str, auto_start: bool) { self.event("fileLastJob", json!({"count": cnt, "autoStart": auto_start})); }
    fn update_folder_files(&self, id: i32, entries: &Vec<FileEntry>, path: String, is_local: bool, only_count: bool) {
        self.event("fileList", json!({"jobId": id, "path": path, "isLocal": is_local, "onlyCount": only_count, "count": entries.len()}));
    }
    fn confirm_delete_files(&self, id: i32, i: i32, name: String) { self.event("fileDeleteConfirm", json!({"jobId": id, "index": i, "name": name})); }
    fn override_file_confirm(&self, id: i32, file_num: i32, to: String, is_upload: bool, is_identical: bool) {
        self.event("fileOverrideConfirm", json!({"jobId": id, "file": file_num, "to": to, "upload": is_upload, "identical": is_identical}));
    }
    fn update_block_input_state(&self, on: bool) { self.event("blockInput", json!({"enabled": on})); }
    fn job_progress(&self, id: i32, file_num: i32, speed: f64, finished_size: f64) {
        self.event("fileProgress", json!({"jobId": id, "file": file_num, "speed": speed, "finished": finished_size}));
    }
    fn adapt_size(&self) {}
    fn on_rgba(&self, display: usize, rgba: &mut scrap::ImageRgb) {
        let raw = &rgba.raw;
        if raw.len() > MAX_FRAME_BYTES {
            self.event("error", json!({"code": "frame-too-large", "bytes": raw.len()}));
            return;
        }
        let (width, height) = *self.display_size.read().unwrap();
        let chunks = (raw.len() + FRAME_CHUNK_BYTES - 1) / FRAME_CHUNK_BYTES;
        self.event("frameBegin", json!({"display": display, "width": width, "height": height, "format": "rgba", "bytes": raw.len(), "chunks": chunks}));
        for (index, chunk) in raw.chunks(FRAME_CHUNK_BYTES).enumerate() {
            self.event("frameChunk", json!({"display": display, "index": index, "hex": hex::encode(chunk)}));
        }
        self.event("frameEnd", json!({"display": display, "chunks": chunks}));
    }
    fn msgbox(&self, msgtype: &str, title: &str, text: &str, link: &str, retry: bool) {
        self.event("status", json!({"messageType": msgtype, "title": title, "text": text, "link": link, "retry": retry}));
    }
    #[cfg(any(target_os = "android", target_os = "ios"))]
    fn clipboard(&self, content: String) { self.event("clipboard", json!({"text": content})); }
    fn cancel_msgbox(&self, tag: &str) { self.event("statusCancelled", json!({"tag": tag})); }
    fn switch_back(&self, id: &str) { self.event("switchBack", json!({"id": id})); }
    fn portable_service_running(&self, running: bool) { self.event("portableService", json!({"running": running})); }
    fn on_voice_call_started(&self) { self.event("voiceCall", json!({"state": "started"})); }
    fn on_voice_call_closed(&self, reason: &str) { self.event("voiceCall", json!({"state": "closed", "reason": reason})); }
    fn on_voice_call_waiting(&self) { self.event("voiceCall", json!({"state": "waiting"})); }
    fn on_voice_call_incoming(&self) { self.event("voiceCall", json!({"state": "incoming"})); }
    fn get_rgba(&self, _display: usize) -> *const u8 { std::ptr::null() }
    fn next_rgba(&self, _display: usize) {}
    #[cfg(all(feature = "vram", feature = "flutter"))]
    fn on_texture(&self, _display: usize, _texture: *mut std::ffi::c_void) {}
    fn set_multiple_windows_session(&self, sessions: Vec<WindowsSession>) { self.event("windowsSessions", json!({"count": sessions.len()})); }
    fn set_current_display(&self, disp_idx: i32) { self.event("currentDisplay", json!({"display": disp_idx})); }
    #[cfg(feature = "flutter")]
    fn is_multi_ui_session(&self) -> bool { false }
    fn update_record_status(&self, start: bool) { self.event("recording", json!({"active": start})); }
    fn update_empty_dirs(&self, _res: ReadEmptyDirsResponse) {}
    fn printer_request(&self, id: i32, path: String) { self.event("printer", json!({"id": id, "path": path})); }
    fn handle_screenshot_resp(&self, sid: String, msg: String) { self.event("screenshot", json!({"id": sid, "message": msg})); }
    fn handle_terminal_response(&self, _response: TerminalResponse) { self.event("terminal", json!({"state": "response"})); }
}

#[derive(Deserialize)]
#[serde(tag = "type", rename_all = "camelCase", deny_unknown_fields)]
enum Command {
    Hello { protocol: String },
    Open {
        session_id: String,
        peer_id: String,
        password: String,
        force_relay: bool,
        grant: Grant,
    },
    Mouse {
        session_id: String,
        mask: i32,
        x: i32,
        y: i32,
        #[serde(default)] alt: bool,
        #[serde(default)] ctrl: bool,
        #[serde(default)] shift: bool,
        #[serde(default)] command: bool,
    },
    Key {
        session_id: String,
        name: String,
        #[serde(default)] down: bool,
        #[serde(default)] press: bool,
        #[serde(default)] alt: bool,
        #[serde(default)] ctrl: bool,
        #[serde(default)] shift: bool,
        #[serde(default)] command: bool,
    },
    Text { session_id: String, text: String },
    Clipboard { session_id: String, text: String },
    File {
        session_id: String,
        action: String,
        #[serde(default)] job_id: i32,
        #[serde(default)] file_type: i32,
        #[serde(default)] path: String,
        #[serde(default)] to: String,
        #[serde(default)] file_num: i32,
        #[serde(default)] include_hidden: bool,
        #[serde(default)] is_remote: bool,
        #[serde(default)] new_name: String,
        #[serde(default)] need_override: bool,
        #[serde(default)] remember: bool,
        #[serde(default)] is_upload: bool,
    },
    Audio { session_id: String, enabled: bool },
    Reconnect { session_id: String, #[serde(default)] force_relay: bool },
    Close { session_id: String },
}

fn valid_id(value: &str, max: usize) -> bool {
    !value.is_empty() && value.len() <= max && value.bytes().all(|b| b.is_ascii_alphanumeric() || b"._:-".contains(&b))
}

fn valid_path(value: &str) -> bool {
    !value.is_empty() && value.len() <= MAX_PATH_BYTES && !value.contains('\0')
}

fn session_for(session_id: &str) -> Result<SidecarSession, &'static str> {
    SESSIONS.lock().unwrap().get(session_id).cloned().ok_or("unknown-session")
}

fn session_for_input(session_id: &str) -> Result<SidecarSession, &'static str> {
    let session = session_for(session_id)?;
    if !session.grant.input { return Err("input-not-granted"); }
    Ok(session)
}

fn restore_audio(entry: &SidecarSession) {
    let disabled = entry.session.get_toggle_option("disable-audio".to_owned());
    if disabled != entry.audio_baseline_disabled {
        entry.session.toggle_option("disable-audio".to_owned());
    }
}

fn handle_file(
    entry: &SidecarSession,
    action: String,
    job_id: i32,
    file_type: i32,
    path: String,
    to: String,
    file_num: i32,
    include_hidden: bool,
    is_remote: bool,
    new_name: String,
    need_override: bool,
    remember: bool,
    is_upload: bool,
) -> Result<(), String> {
    if !entry.grant.file_transfer { return Err("file-transfer-not-granted".into()); }
    if job_id < 0 || file_num < 0 { return Err("invalid-file-job".into()); }
    match action.as_str() {
        "readRemoteDir" => {
            if !valid_path(&path) { return Err("invalid-file-path".into()); }
            entry.session.read_remote_dir(path, include_hidden);
        }
        "readEmptyDirs" => {
            if !valid_path(&path) { return Err("invalid-file-path".into()); }
            entry.session.read_empty_dirs(path, include_hidden);
        }
        "send" => {
            if !valid_path(&path) || !valid_path(&to) { return Err("invalid-file-path".into()); }
            entry.session.send_files(job_id, file_type, path, to, file_num, include_hidden, is_remote);
        }
        "add" => {
            if !valid_path(&path) || !valid_path(&to) { return Err("invalid-file-path".into()); }
            entry.session.add_job(job_id, file_type, path, to, file_num, include_hidden, is_remote);
        }
        "resume" => entry.session.resume_job(job_id, is_remote),
        "cancel" => entry.session.cancel_job(job_id),
        "createDir" => {
            if !valid_path(&path) { return Err("invalid-file-path".into()); }
            entry.session.create_dir(job_id, path, is_remote);
        }
        "removeFile" => {
            if !valid_path(&path) { return Err("invalid-file-path".into()); }
            entry.session.remove_file(job_id, path, file_num, is_remote);
        }
        "removeDir" => {
            if !valid_path(&path) { return Err("invalid-file-path".into()); }
            entry.session.remove_dir(job_id, path, is_remote);
        }
        "removeDirAll" => {
            if !valid_path(&path) { return Err("invalid-file-path".into()); }
            entry.session.remove_dir_all(job_id, path, is_remote, include_hidden);
        }
        "rename" => {
            if !valid_path(&path) || new_name.is_empty() || new_name.len() > 255 || new_name.contains(['/', '\\', '\0']) {
                return Err("invalid-file-rename".into());
            }
            entry.session.rename_file(job_id, path, new_name, is_remote);
        }
        "confirmOverride" => entry.session.set_confirm_override_file(job_id, file_num, need_override, remember, is_upload),
        _ => return Err("unsupported-file-action".into()),
    }
    Ok(())
}

fn handle(command: Command) -> Result<Value, String> {
    match command {
        Command::Hello { protocol } => {
            if protocol != PROTOCOL { return Err("protocol-mismatch".into()); }
            Ok(json!({"protocol": PROTOCOL, "type": "hello", "capabilities": ["display", "input", "clipboard", "fileTransfer", "audio", "reconnect"], "control": "stdio"}))
        }
        Command::Open { session_id, peer_id, password, force_relay, grant } => {
            if !valid_id(&session_id, 160) || !valid_id(&peer_id, 160) { return Err("invalid-session-or-peer-id".into()); }
            if password.is_empty() || password.len() > 256 || password.bytes().any(|b| b.is_ascii_control()) { return Err("invalid-ephemeral-password".into()); }
            if !grant.display { return Err("display-grant-required".into()); }
            let mut sessions = SESSIONS.lock().unwrap();
            if sessions.contains_key(&session_id) { return Err("session-already-open".into()); }
            let handler = BridgeHandler { session_id: session_id.clone(), ..Default::default() };
            let session: Session<BridgeHandler> = Session {
                password,
                args: if force_relay { vec!["--relay".to_owned()] } else { Vec::new() },
                ui_handler: handler,
                server_keyboard_enabled: Arc::new(RwLock::new(grant.input)),
                server_file_transfer_enabled: Arc::new(RwLock::new(grant.file_transfer)),
                server_clipboard_enabled: Arc::new(RwLock::new(grant.clipboard)),
                reconnect_count: Arc::new(AtomicUsize::new(0)),
                ..Default::default()
            };
            session.lc.write().unwrap().initialize(peer_id, ConnType::DEFAULT_CONN, None, force_relay, None, None, None);
            let audio_baseline_disabled = session.get_toggle_option("disable-audio".to_owned());
            if !grant.audio && !audio_baseline_disabled {
                session.toggle_option("disable-audio".to_owned());
            }
            session.reconnect(force_relay);
            sessions.insert(session_id.clone(), SidecarSession { session, grant, audio_baseline_disabled });
            Ok(json!({"protocol": PROTOCOL, "type": "opening", "sessionId": session_id, "grant": {"display": grant.display, "input": grant.input, "clipboard": grant.clipboard, "fileTransfer": grant.file_transfer, "audio": grant.audio}}))
        }
        Command::Mouse { session_id, mask, x, y, alt, ctrl, shift, command } => {
            let entry = session_for_input(&session_id).map_err(str::to_owned)?;
            entry.session.send_mouse(mask, x, y, alt, ctrl, shift, command);
            Ok(json!({"protocol": PROTOCOL, "type": "accepted", "sessionId": session_id, "operation": "mouse"}))
        }
        Command::Key { session_id, name, down, press, alt, ctrl, shift, command } => {
            if name.is_empty() || name.len() > 64 { return Err("invalid-key".into()); }
            let entry = session_for_input(&session_id).map_err(str::to_owned)?;
            entry.session.input_key(&name, down, press, alt, ctrl, shift, command);
            Ok(json!({"protocol": PROTOCOL, "type": "accepted", "sessionId": session_id, "operation": "key"}))
        }
        Command::Text { session_id, text } => {
            if text.len() > 64 * 1024 { return Err("text-too-large".into()); }
            let entry = session_for_input(&session_id).map_err(str::to_owned)?;
            entry.session.input_string(&text);
            Ok(json!({"protocol": PROTOCOL, "type": "accepted", "sessionId": session_id, "operation": "text"}))
        }
        Command::Clipboard { session_id, text } => {
            if text.len() > MAX_CLIPBOARD_BYTES { return Err("clipboard-too-large".into()); }
            let entry = session_for(&session_id).map_err(str::to_owned)?;
            if !entry.grant.clipboard { return Err("clipboard-not-granted".into()); }
            let mut message = Message::new();
            message.set_multi_clipboards(MultiClipboards {
                clipboards: vec![Clipboard {
                    compress: false,
                    content: text.into_bytes().into(),
                    format: ClipboardFormat::Text.into(),
                    ..Default::default()
                }],
                ..Default::default()
            });
            entry.session.send(Data::Message(message));
            Ok(json!({"protocol": PROTOCOL, "type": "accepted", "sessionId": session_id, "operation": "clipboard"}))
        }
        Command::File { session_id, action, job_id, file_type, path, to, file_num, include_hidden, is_remote, new_name, need_override, remember, is_upload } => {
            let entry = session_for(&session_id).map_err(str::to_owned)?;
            handle_file(&entry, action, job_id, file_type, path, to, file_num, include_hidden, is_remote, new_name, need_override, remember, is_upload)?;
            Ok(json!({"protocol": PROTOCOL, "type": "accepted", "sessionId": session_id, "operation": "file"}))
        }
        Command::Audio { session_id, enabled } => {
            let entry = session_for(&session_id).map_err(str::to_owned)?;
            if enabled && !entry.grant.audio { return Err("audio-not-granted".into()); }
            let disabled = entry.session.get_toggle_option("disable-audio".to_owned());
            if disabled == enabled {
                entry.session.toggle_option("disable-audio".to_owned());
            }
            Ok(json!({"protocol": PROTOCOL, "type": "accepted", "sessionId": session_id, "operation": "audio", "enabled": enabled}))
        }
        Command::Reconnect { session_id, force_relay } => {
            let entry = session_for(&session_id).map_err(str::to_owned)?;
            entry.session.reconnect(force_relay);
            Ok(json!({"protocol": PROTOCOL, "type": "reconnecting", "sessionId": session_id, "forceRelay": force_relay}))
        }
        Command::Close { session_id } => {
            let entry = SESSIONS.lock().unwrap().remove(&session_id).ok_or_else(|| "unknown-session".to_owned())?;
            restore_audio(&entry);
            entry.session.close();
            Ok(json!({"protocol": PROTOCOL, "type": "closed", "sessionId": session_id}))
        }
    }
}

fn main() {
    emit(json!({"protocol": PROTOCOL, "type": "boot", "pid": std::process::id()}));
    let stdin = io::stdin();
    for result in stdin.lock().lines() {
        let line = match result {
            Ok(line) => line,
            Err(error) => { emit(json!({"protocol": PROTOCOL, "type": "error", "code": "stdin", "message": error.to_string()})); break; }
        };
        if line.len() > MAX_LINE_BYTES {
            emit(json!({"protocol": PROTOCOL, "type": "error", "code": "command-too-large"}));
            continue;
        }
        let response = serde_json::from_str::<Command>(&line)
            .map_err(|error| format!("invalid-command:{error}"))
            .and_then(handle);
        match response {
            Ok(value) => emit(value),
            Err(message) => emit(json!({"protocol": PROTOCOL, "type": "error", "code": message})),
        }
    }
    let sessions = std::mem::take(&mut *SESSIONS.lock().unwrap());
    for (_, entry) in sessions {
        restore_audio(&entry);
        entry.session.close();
    }
    emit(json!({"protocol": PROTOCOL, "type": "shutdown"}));
}
