//! Mahayana-owned gateway semantics shared by the CLI stdio server and future
//! Desktop/WebSocket/API adapters. This module adapts the existing Rust runtime;
//! it does not introduce a second agent kernel or an external Hermes runtime.

use mahayana_core::MessageRole;
use mahayana_core::RuntimeActivityStatus;
use mahayana_core::RuntimeEvent;
use serde_json::Value;
use serde_json::json;
use std::collections::HashMap;
use std::collections::VecDeque;

pub const GATEWAY_PROTOCOL_VERSION: &str = "1";
pub const DEFAULT_REPLAY_EVENTS_PER_SESSION: usize = 512;
pub const DEFAULT_REPLAY_BYTES_PER_SESSION: usize = 4 * 1024 * 1024;
pub const DEFAULT_REPLAY_SESSIONS: usize = 64;

#[derive(Debug, Clone, PartialEq)]
pub struct GatewayEvent {
    pub protocol_version: String,
    pub replay_epoch: String,
    pub session_id: String,
    pub turn_id: String,
    pub seq: u64,
    pub timestamp_ms: i64,
    pub event_type: String,
    pub payload: Value,
}

impl GatewayEvent {
    pub fn to_value(&self) -> Value {
        json!({
            "protocol_version": self.protocol_version,
            "replay_epoch": self.replay_epoch,
            "session_id": self.session_id,
            "turn_id": self.turn_id,
            "seq": self.seq,
            "timestamp_ms": self.timestamp_ms,
            "type": self.event_type,
            "payload": self.payload,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct GatewayEventDraft {
    pub session_id: String,
    pub turn_id: String,
    pub timestamp_ms: i64,
    pub event_type: String,
    pub payload: Value,
}

impl GatewayEventDraft {
    pub fn new(
        session_id: impl Into<String>,
        turn_id: impl Into<String>,
        timestamp_ms: i64,
        event_type: impl Into<String>,
        payload: Value,
    ) -> Self {
        Self {
            session_id: session_id.into(),
            turn_id: turn_id.into(),
            timestamp_ms,
            event_type: event_type.into(),
            payload,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ReplayLimits {
    pub max_events_per_session: usize,
    pub max_bytes_per_session: usize,
    pub max_sessions: usize,
}

impl Default for ReplayLimits {
    fn default() -> Self {
        Self {
            max_events_per_session: DEFAULT_REPLAY_EVENTS_PER_SESSION,
            max_bytes_per_session: DEFAULT_REPLAY_BYTES_PER_SESSION,
            max_sessions: DEFAULT_REPLAY_SESSIONS,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct ReplaySlice {
    pub replay_epoch: String,
    pub session_id: String,
    pub last_seen: u64,
    pub latest_seq: u64,
    pub truncated: bool,
    pub events: Vec<GatewayEvent>,
}

impl ReplaySlice {
    pub fn to_value(&self) -> Value {
        json!({
            "replay_epoch": self.replay_epoch,
            "session_id": self.session_id,
            "last_seen": self.last_seen,
            "latest_seq": self.latest_seq,
            "truncated": self.truncated,
            "events": self.events.iter().map(GatewayEvent::to_value).collect::<Vec<_>>(),
        })
    }
}

#[derive(Debug, Default)]
struct SessionReplay {
    next_seq: u64,
    bytes: usize,
    evicted_through: u64,
    events: VecDeque<(GatewayEvent, usize)>,
}

#[derive(Debug)]
pub struct ReplayStore {
    epoch: String,
    limits: ReplayLimits,
    sessions: HashMap<String, SessionReplay>,
    session_order: VecDeque<String>,
    forgotten_latest: HashMap<String, u64>,
    forgotten_order: VecDeque<String>,
}

impl ReplayStore {
    pub fn new(limits: ReplayLimits) -> Self {
        Self::with_epoch(limits, uuid::Uuid::new_v4().simple().to_string())
    }

    pub fn with_epoch(limits: ReplayLimits, epoch: impl Into<String>) -> Self {
        Self {
            epoch: epoch.into(),
            limits: ReplayLimits {
                max_events_per_session: limits.max_events_per_session.max(1),
                max_bytes_per_session: limits.max_bytes_per_session.max(1),
                max_sessions: limits.max_sessions.max(1),
            },
            sessions: HashMap::new(),
            session_order: VecDeque::new(),
            forgotten_latest: HashMap::new(),
            forgotten_order: VecDeque::new(),
        }
    }

    pub fn epoch(&self) -> &str {
        &self.epoch
    }

    pub fn push(&mut self, draft: GatewayEventDraft) -> GatewayEvent {
        self.ensure_session(&draft.session_id);
        let session = self
            .sessions
            .get_mut(&draft.session_id)
            .expect("session exists after ensure_session");
        session.next_seq = session.next_seq.saturating_add(1);
        let event = GatewayEvent {
            protocol_version: GATEWAY_PROTOCOL_VERSION.to_string(),
            replay_epoch: self.epoch.clone(),
            session_id: draft.session_id,
            turn_id: draft.turn_id,
            seq: session.next_seq,
            timestamp_ms: draft.timestamp_ms,
            event_type: draft.event_type,
            payload: draft.payload,
        };
        let encoded_size = event.to_value().to_string().len();

        // An oversized frame consumes a sequence number but is not retained;
        // replay then reports a hole so the client must refetch history.
        if encoded_size > self.limits.max_bytes_per_session {
            session.evicted_through = event.seq;
            return event;
        }

        session.events.push_back((event.clone(), encoded_size));
        session.bytes = session.bytes.saturating_add(encoded_size);
        while session.events.len() > self.limits.max_events_per_session
            || session.bytes > self.limits.max_bytes_per_session
        {
            if let Some((removed, bytes)) = session.events.pop_front() {
                session.bytes = session.bytes.saturating_sub(bytes);
                session.evicted_through = session.evicted_through.max(removed.seq);
            } else {
                break;
            }
        }
        event
    }

    pub fn since(&self, session_id: &str, last_seen: u64) -> ReplaySlice {
        if let Some(session) = self.sessions.get(session_id) {
            return ReplaySlice {
                replay_epoch: self.epoch.clone(),
                session_id: session_id.to_string(),
                last_seen,
                latest_seq: session.next_seq,
                // last_seen > next_seq catches a cache-generation reset and
                // refuses to silently present an empty replay as complete.
                truncated: last_seen < session.evicted_through || last_seen > session.next_seq,
                events: session
                    .events
                    .iter()
                    .filter(|(event, _)| event.seq > last_seen)
                    .map(|(event, _)| event.clone())
                    .collect(),
            };
        }
        let latest_seq = self.forgotten_latest.get(session_id).copied().unwrap_or_default();
        ReplaySlice {
            replay_epoch: self.epoch.clone(),
            session_id: session_id.to_string(),
            last_seen,
            latest_seq,
            truncated: last_seen > 0 || last_seen < latest_seq,
            events: Vec::new(),
        }
    }

    fn ensure_session(&mut self, session_id: &str) {
        if self.sessions.contains_key(session_id) {
            if let Some(index) = self.session_order.iter().position(|item| item == session_id) {
                self.session_order.remove(index);
            }
            self.session_order.push_back(session_id.to_string());
            return;
        }

        while self.sessions.len() >= self.limits.max_sessions {
            let Some(oldest) = self.session_order.pop_front() else {
                break;
            };
            if let Some(removed) = self.sessions.remove(&oldest) {
                self.remember_forgotten(oldest, removed.next_seq);
            }
        }

        let mut session = SessionReplay::default();
        session.next_seq = self.forgotten_latest.remove(session_id).unwrap_or_default();
        if let Some(index) = self
            .forgotten_order
            .iter()
            .position(|item| item == session_id)
        {
            self.forgotten_order.remove(index);
        }
        session.evicted_through = session.next_seq;
        self.sessions.insert(session_id.to_string(), session);
        self.session_order.push_back(session_id.to_string());
    }

    fn remember_forgotten(&mut self, session_id: String, latest_seq: u64) {
        self.forgotten_latest.insert(session_id.clone(), latest_seq);
        if let Some(index) = self
            .forgotten_order
            .iter()
            .position(|item| item == &session_id)
        {
            self.forgotten_order.remove(index);
        }
        self.forgotten_order.push_back(session_id);
        while self.forgotten_order.len() > self.limits.max_sessions {
            if let Some(oldest) = self.forgotten_order.pop_front() {
                self.forgotten_latest.remove(&oldest);
            }
        }
    }
}

#[derive(Debug, Default)]
pub struct RuntimeProjection {
    sessions_by_turn: HashMap<String, String>,
}

impl RuntimeProjection {
    pub fn register_turn(&mut self, turn_id: impl Into<String>, session_id: impl Into<String>) {
        self.sessions_by_turn.insert(turn_id.into(), session_id.into());
    }

    fn forget_turn(&mut self, turn_id: &str) {
        self.sessions_by_turn.remove(turn_id);
    }

    fn session_for_turn(&self, turn_id: &str) -> Option<&str> {
        self.sessions_by_turn.get(turn_id).map(String::as_str)
    }

    pub fn project(&mut self, event: &RuntimeEvent, timestamp_ms: i64) -> Vec<GatewayEventDraft> {
        match event {
            RuntimeEvent::Ready { .. }
            | RuntimeEvent::Lagged { .. }
            | RuntimeEvent::ProviderDegraded { .. } => Vec::new(),
            RuntimeEvent::MessageDelta {
                operation_id,
                conversation_id,
                delta,
            } => {
                self.register_turn(operation_id.0.clone(), conversation_id.0.clone());
                vec![GatewayEventDraft::new(
                    conversation_id.0.clone(),
                    operation_id.0.clone(),
                    timestamp_ms,
                    "message.delta",
                    json!({ "text": delta }),
                )]
            }
            RuntimeEvent::MessageCompleted { operation_id, message } => {
                self.register_turn(operation_id.0.clone(), message.conversation_id.0.clone());
                if message.role != MessageRole::Assistant {
                    return Vec::new();
                }
                vec![GatewayEventDraft::new(
                    message.conversation_id.0.clone(),
                    operation_id.0.clone(),
                    timestamp_ms,
                    "message.complete",
                    json!({
                        "text": message.text,
                        "messageId": message.id.0,
                        "createdAtMs": message.created_at_ms,
                    }),
                )]
            }
            RuntimeEvent::ModelUsageUpdated { operation_id, usage } => self.turn_draft(
                operation_id.0.as_str(),
                timestamp_ms,
                "session.usage",
                serde_json::to_value(usage).unwrap_or(Value::Null),
            ),
            RuntimeEvent::ApprovalRequested {
                operation_id,
                approval_id,
                title,
                details,
            } => self.turn_draft(
                operation_id.0.as_str(),
                timestamp_ms,
                "approval.request",
                json!({
                    "approvalId": approval_id.0,
                    "title": title,
                    "details": details,
                }),
            ),
            RuntimeEvent::PluginProgress {
                operation_id,
                plugin_id,
                tool,
                progress,
                total,
                message,
            } => self.turn_draft(
                operation_id.0.as_str(),
                timestamp_ms,
                "tool.progress",
                json!({
                    "toolId": format!("plugin:{plugin_id}:{tool}"),
                    "name": tool,
                    "pluginId": plugin_id,
                    "progress": progress,
                    "total": total,
                    "message": message,
                }),
            ),
            RuntimeEvent::AgentActivity {
                operation_id,
                step_id,
                kind,
                title,
                detail,
                status,
                metadata,
            } => {
                if kind == "reasoning" || kind == "thinking" {
                    return self.turn_draft(
                        operation_id.0.as_str(),
                        timestamp_ms,
                        "reasoning.delta",
                        json!({
                            "text": detail.as_deref().unwrap_or(title),
                            "status": activity_status(*status),
                        }),
                    );
                }
                let event_type = match status {
                    RuntimeActivityStatus::Running => "tool.start",
                    RuntimeActivityStatus::Completed | RuntimeActivityStatus::Failed => "tool.complete",
                };
                self.turn_draft(
                    operation_id.0.as_str(),
                    timestamp_ms,
                    event_type,
                    json!({
                        "toolId": step_id,
                        "name": title,
                        "kind": kind,
                        "detail": detail,
                        "status": activity_status(*status),
                        "metadata": metadata,
                    }),
                )
            }
            RuntimeEvent::OperationCompleted { operation_id } => {
                let drafts = self.turn_draft(
                    operation_id.0.as_str(),
                    timestamp_ms,
                    "turn.complete",
                    json!({}),
                );
                self.forget_turn(operation_id.0.as_str());
                drafts
            }
            RuntimeEvent::OperationFailed {
                operation_id,
                code,
                message,
            } => {
                let drafts = self.turn_draft(
                    operation_id.0.as_str(),
                    timestamp_ms,
                    "turn.failed",
                    json!({ "code": code, "message": message }),
                );
                self.forget_turn(operation_id.0.as_str());
                drafts
            }
        }
    }

    fn turn_draft(
        &self,
        turn_id: &str,
        timestamp_ms: i64,
        event_type: &str,
        payload: Value,
    ) -> Vec<GatewayEventDraft> {
        self.session_for_turn(turn_id)
            .map(|session_id| {
                vec![GatewayEventDraft::new(
                    session_id,
                    turn_id,
                    timestamp_ms,
                    event_type,
                    payload,
                )]
            })
            .unwrap_or_default()
    }
}

fn activity_status(status: RuntimeActivityStatus) -> &'static str {
    match status {
        RuntimeActivityStatus::Running => "running",
        RuntimeActivityStatus::Completed => "completed",
        RuntimeActivityStatus::Failed => "failed",
    }
}

#[derive(Debug)]
pub struct GatewayState {
    projection: RuntimeProjection,
    replay: ReplayStore,
}

impl GatewayState {
    pub fn new(limits: ReplayLimits) -> Self {
        Self {
            projection: RuntimeProjection::default(),
            replay: ReplayStore::new(limits),
        }
    }

    #[cfg(test)]
    fn with_epoch(limits: ReplayLimits, epoch: impl Into<String>) -> Self {
        Self {
            projection: RuntimeProjection::default(),
            replay: ReplayStore::with_epoch(limits, epoch),
        }
    }

    pub fn replay_epoch(&self) -> &str {
        self.replay.epoch()
    }

    pub fn register_turn(&mut self, turn_id: impl Into<String>, session_id: impl Into<String>) {
        self.projection.register_turn(turn_id, session_id);
    }

    pub fn emit(
        &mut self,
        session_id: impl Into<String>,
        turn_id: impl Into<String>,
        timestamp_ms: i64,
        event_type: impl Into<String>,
        payload: Value,
    ) -> GatewayEvent {
        self.replay.push(GatewayEventDraft::new(
            session_id,
            turn_id,
            timestamp_ms,
            event_type,
            payload,
        ))
    }

    pub fn ingest_runtime_event(
        &mut self,
        event: &RuntimeEvent,
        timestamp_ms: i64,
    ) -> Vec<GatewayEvent> {
        self.projection
            .project(event, timestamp_ms)
            .into_iter()
            .map(|draft| self.replay.push(draft))
            .collect()
    }

    pub fn replay_since(&self, session_id: &str, last_seen: u64) -> ReplaySlice {
        self.replay.since(session_id, last_seen)
    }
}

pub fn event_notification(event: &GatewayEvent) -> Value {
    json!({
        "jsonrpc": "2.0",
        "method": "event",
        "params": event.to_value(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use mahayana_core::ConversationId;
    use mahayana_core::OperationId;

    fn draft(session: &str, turn: &str, index: i64) -> GatewayEventDraft {
        GatewayEventDraft::new(
            session,
            turn,
            index,
            "message.delta",
            json!({ "text": index.to_string() }),
        )
    }

    #[test]
    fn replay_sequence_is_monotonic_and_since_is_exact() {
        let mut replay = ReplayStore::with_epoch(ReplayLimits::default(), "epoch-1");
        let one = replay.push(draft("s1", "t1", 1));
        let two = replay.push(draft("s1", "t1", 2));
        let three = replay.push(draft("s1", "t1", 3));
        assert_eq!((one.seq, two.seq, three.seq), (1, 2, 3));
        let slice = replay.since("s1", 1);
        assert!(!slice.truncated);
        assert_eq!(slice.latest_seq, 3);
        assert_eq!(
            slice.events.iter().map(|event| event.seq).collect::<Vec<_>>(),
            vec![2, 3]
        );
    }

    #[test]
    fn replay_eviction_marks_the_gap_as_truncated() {
        let limits = ReplayLimits {
            max_events_per_session: 2,
            max_bytes_per_session: 1024 * 1024,
            max_sessions: 2,
        };
        let mut replay = ReplayStore::with_epoch(limits, "epoch-1");
        replay.push(draft("s1", "t1", 1));
        replay.push(draft("s1", "t1", 2));
        replay.push(draft("s1", "t1", 3));
        let stale = replay.since("s1", 0);
        assert!(stale.truncated);
        assert_eq!(stale.latest_seq, 3);
        assert_eq!(stale.events.len(), 2);
        let current = replay.since("s1", 1);
        assert!(!current.truncated);
    }

    #[test]
    fn stale_sequence_after_cache_generation_reset_is_not_silently_accepted() {
        let limits = ReplayLimits {
            max_events_per_session: 4,
            max_bytes_per_session: 1024 * 1024,
            max_sessions: 1,
        };
        let mut replay = ReplayStore::with_epoch(limits, "epoch-1");
        replay.push(draft("s1", "t1", 1));
        replay.push(draft("s2", "t2", 2));
        let forgotten = replay.since("s1", 1);
        assert!(!forgotten.truncated);
        replay.push(draft("s3", "t3", 3));
        // The tombstone for s1 may be gone, but a client carrying a non-zero
        // sequence can never receive a false complete replay.
        assert!(replay.since("s1", 1).truncated);
    }

    #[test]
    fn activity_updates_keep_one_turn_and_stable_tool_id() {
        let mut state = GatewayState::with_epoch(ReplayLimits::default(), "epoch-1");
        state.register_turn("operation:1", "conversation:1");
        let running = RuntimeEvent::AgentActivity {
            operation_id: OperationId("operation:1".into()),
            step_id: "step-7".into(),
            kind: "command_execution".into(),
            title: "Run tests".into(),
            detail: Some("cargo test".into()),
            status: RuntimeActivityStatus::Running,
            metadata: None,
        };
        let completed = RuntimeEvent::AgentActivity {
            operation_id: OperationId("operation:1".into()),
            step_id: "step-7".into(),
            kind: "command_execution".into(),
            title: "Run tests".into(),
            detail: Some("passed".into()),
            status: RuntimeActivityStatus::Completed,
            metadata: None,
        };
        let first = state.ingest_runtime_event(&running, 1).remove(0);
        let second = state.ingest_runtime_event(&completed, 2).remove(0);
        assert_eq!(first.session_id, "conversation:1");
        assert_eq!(first.turn_id, second.turn_id);
        assert_eq!(first.payload["toolId"], second.payload["toolId"]);
        assert_eq!(first.event_type, "tool.start");
        assert_eq!(second.event_type, "tool.complete");
        assert_eq!((first.seq, second.seq), (1, 2));
    }

    #[test]
    fn reasoning_activity_is_not_misrepresented_as_a_tool_card() {
        let mut state = GatewayState::with_epoch(ReplayLimits::default(), "epoch-1");
        state.register_turn("operation:1", "conversation:1");
        let event = RuntimeEvent::AgentActivity {
            operation_id: OperationId("operation:1".into()),
            step_id: "reasoning-1".into(),
            kind: "reasoning".into(),
            title: "Thinking".into(),
            detail: Some("checking the repository".into()),
            status: RuntimeActivityStatus::Running,
            metadata: None,
        };
        let projected = state.ingest_runtime_event(&event, 1).remove(0);
        assert_eq!(projected.event_type, "reasoning.delta");
        assert_eq!(projected.payload["text"], "checking the repository");
    }

    #[test]
    fn message_delta_registers_turn_for_lifecycle_completion() {
        let mut state = GatewayState::with_epoch(ReplayLimits::default(), "epoch-1");
        let delta = RuntimeEvent::MessageDelta {
            operation_id: OperationId("operation:1".into()),
            conversation_id: ConversationId("conversation:1".into()),
            delta: "hello".into(),
        };
        let completed = RuntimeEvent::OperationCompleted {
            operation_id: OperationId("operation:1".into()),
        };
        let one = state.ingest_runtime_event(&delta, 1).remove(0);
        let two = state.ingest_runtime_event(&completed, 2).remove(0);
        assert_eq!(one.event_type, "message.delta");
        assert_eq!(two.event_type, "turn.complete");
        assert_eq!(one.session_id, two.session_id);
        assert_eq!((one.seq, two.seq), (1, 2));
    }
}
