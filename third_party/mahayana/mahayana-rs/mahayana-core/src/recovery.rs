//! Durable Mahayana session snapshot and recovery contracts.
//!
//! The product persists provider-neutral state. A resumed session can select a
//! compatible backend and reconstruct its task/goal/checkpoint/permission
//! state without deserializing Codex or Grok internal session structures.

use crate::ConversationId;
use crate::capability::goal::GoalGraph;
use crate::capability::kernel::BackendCapabilities;
use crate::capability::kernel::InputEnvelope;
use crate::capability::kernel::TaskRecord;
use crate::capability::permission::DurablePermissionState;
use crate::capability::workspace::CheckpointStore;
use serde::Deserialize;
use serde::Serialize;
use std::collections::BTreeMap;

pub const SESSION_SNAPSHOT_VERSION: u32 = 1;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionSnapshot {
    pub version: u32,
    pub revision: u64,
    pub session_id: String,
    pub conversation_id: ConversationId,
    pub backend_id: String,
    pub backend_capabilities: BackendCapabilities,
    pub task: TaskRecord,
    pub goal: Option<GoalGraph>,
    pub checkpoints: CheckpointStore,
    pub permissions: DurablePermissionState,
    pub created_at_ms: i64,
    pub updated_at_ms: i64,
}

impl SessionSnapshot {
    pub fn validate(&self) -> Result<(), RecoveryError> {
        if self.version != SESSION_SNAPSHOT_VERSION {
            return Err(RecoveryError::UnsupportedVersion(self.version));
        }
        if self.session_id.trim().is_empty() {
            return Err(RecoveryError::EmptyField("sessionId"));
        }
        if self.backend_id.trim().is_empty() {
            return Err(RecoveryError::EmptyField("backendId"));
        }
        if self.updated_at_ms < self.created_at_ms {
            return Err(RecoveryError::InvalidTimestampOrder);
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum JournalEvent {
    SessionCreated {
        session_id: String,
        backend_id: String,
    },
    InputQueued {
        input: InputEnvelope,
    },
    InputSteered {
        input: InputEnvelope,
    },
    AttemptStarted {
        attempt_id: String,
        fingerprint: String,
    },
    AttemptFinished {
        attempt_id: String,
        succeeded: bool,
    },
    OracleUpdated {
        name: String,
        status: String,
        evidence: Option<String>,
    },
    CheckpointRecorded {
        turn_index: u64,
        checkpoint_id: String,
    },
    Rewound {
        target_turn: u64,
    },
    Paused,
    Resumed,
    ContextCompacted {
        generation: u64,
    },
    SessionCompleted,
    SessionFailed {
        reason: String,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct JournalEntry {
    pub sequence: u64,
    pub occurred_at_ms: i64,
    pub event: JournalEvent,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionJournal {
    entries: Vec<JournalEntry>,
}

impl SessionJournal {
    pub fn append(&mut self, occurred_at_ms: i64, event: JournalEvent) -> u64 {
        let sequence = self
            .entries
            .last()
            .map(|entry| entry.sequence.saturating_add(1))
            .unwrap_or(1);
        self.entries.push(JournalEntry {
            sequence,
            occurred_at_ms,
            event,
        });
        sequence
    }

    pub fn entries(&self) -> &[JournalEntry] {
        &self.entries
    }

    pub fn after(&self, sequence: u64) -> Vec<&JournalEntry> {
        self.entries
            .iter()
            .filter(|entry| entry.sequence > sequence)
            .collect()
    }
}

/// Storage-agnostic optimistic-concurrency state machine. Host implementations
/// persist these records to SQLite/files/cloud as appropriate, but all writes
/// use revision compare-and-swap semantics to avoid stale session overwrites.
#[derive(Debug, Default)]
pub struct RecoveryIndex {
    snapshots: BTreeMap<String, SessionSnapshot>,
    journals: BTreeMap<String, SessionJournal>,
}

impl RecoveryIndex {
    pub fn create(
        &mut self,
        snapshot: SessionSnapshot,
        journal: SessionJournal,
    ) -> Result<(), RecoveryError> {
        snapshot.validate()?;
        if snapshot.revision != 1 {
            return Err(RecoveryError::InitialRevisionMustBeOne);
        }
        if self.snapshots.contains_key(&snapshot.session_id) {
            return Err(RecoveryError::SessionAlreadyExists(snapshot.session_id));
        }
        let session_id = snapshot.session_id.clone();
        self.snapshots.insert(session_id.clone(), snapshot);
        self.journals.insert(session_id, journal);
        Ok(())
    }

    pub fn load(&self, session_id: &str) -> Option<&SessionSnapshot> {
        self.snapshots.get(session_id)
    }

    pub fn journal(&self, session_id: &str) -> Option<&SessionJournal> {
        self.journals.get(session_id)
    }

    pub fn replace(
        &mut self,
        expected_revision: u64,
        mut snapshot: SessionSnapshot,
    ) -> Result<u64, RecoveryError> {
        snapshot.validate()?;
        let current = self
            .snapshots
            .get(&snapshot.session_id)
            .ok_or_else(|| RecoveryError::SessionNotFound(snapshot.session_id.clone()))?;
        if current.revision != expected_revision {
            return Err(RecoveryError::RevisionConflict {
                expected: expected_revision,
                actual: current.revision,
            });
        }
        let next = expected_revision.saturating_add(1);
        snapshot.revision = next;
        self.snapshots.insert(snapshot.session_id.clone(), snapshot);
        Ok(next)
    }

    pub fn append(
        &mut self,
        session_id: &str,
        occurred_at_ms: i64,
        event: JournalEvent,
    ) -> Result<u64, RecoveryError> {
        if !self.snapshots.contains_key(session_id) {
            return Err(RecoveryError::SessionNotFound(session_id.to_string()));
        }
        Ok(self
            .journals
            .entry(session_id.to_string())
            .or_default()
            .append(occurred_at_ms, event))
    }
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum RecoveryError {
    #[error("unsupported session snapshot version: {0}")]
    UnsupportedVersion(u32),
    #[error("field must not be empty: {0}")]
    EmptyField(&'static str),
    #[error("session updated timestamp predates created timestamp")]
    InvalidTimestampOrder,
    #[error("initial session revision must be 1")]
    InitialRevisionMustBeOne,
    #[error("session already exists: {0}")]
    SessionAlreadyExists(String),
    #[error("session was not found: {0}")]
    SessionNotFound(String),
    #[error("session revision conflict: expected {expected}, actual {actual}")]
    RevisionConflict { expected: u64, actual: u64 },
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::BuildProfile;
    use crate::capability::kernel::ContextWindow;
    use crate::capability::kernel::InputQueue;
    use crate::capability::kernel::TaskState;
    use crate::capability::kernel::VerificationMode;

    fn snapshot() -> SessionSnapshot {
        SessionSnapshot {
            version: SESSION_SNAPSHOT_VERSION,
            revision: 1,
            session_id: "session:1".into(),
            conversation_id: ConversationId("mahayana:agent:assistant".into()),
            backend_id: "responses".into(),
            backend_capabilities: BackendCapabilities {
                sandbox: true,
                headless: true,
                ..BackendCapabilities::default()
            },
            task: TaskRecord {
                id: "T1".into(),
                goal: "recover".into(),
                state: TaskState::Paused,
                verification_mode: VerificationMode::ObjectiveRequired,
                oracles: vec![],
                attempts: vec![],
                queued_inputs: InputQueue::default(),
                context_window: ContextWindow::new(),
            },
            goal: None,
            checkpoints: CheckpointStore::default(),
            permissions: DurablePermissionState::default(),
            created_at_ms: 1,
            updated_at_ms: 2,
        }
    }

    #[test]
    fn snapshot_roundtrip_is_provider_neutral() {
        let snapshot = snapshot();
        let json = serde_json::to_string(&snapshot).expect("encode");
        assert!(!json.contains("codex"));
        assert!(!json.contains("grok"));
        let decoded: SessionSnapshot = serde_json::from_str(&json).expect("decode");
        assert_eq!(decoded, snapshot);
        assert_eq!(decoded.task.state, TaskState::Paused);
    }

    #[test]
    fn recovery_index_rejects_stale_writes() {
        let mut index = RecoveryIndex::default();
        index
            .create(snapshot(), SessionJournal::default())
            .expect("create");
        let mut next = index.load("session:1").expect("load").clone();
        next.updated_at_ms = 3;
        assert_eq!(index.replace(1, next.clone()).expect("replace"), 2);
        assert!(matches!(
            index.replace(1, next),
            Err(RecoveryError::RevisionConflict {
                expected: 1,
                actual: 2
            })
        ));
    }

    #[test]
    fn journal_sequences_are_monotonic() {
        let mut journal = SessionJournal::default();
        assert_eq!(journal.append(1, JournalEvent::Paused), 1);
        assert_eq!(journal.append(2, JournalEvent::Resumed), 2);
        assert_eq!(journal.after(1).len(), 1);
    }

    #[test]
    fn surface_profile_is_not_embedded_in_recovery_identity() {
        let _ = BuildProfile::DesktopFull;
        let json = serde_json::to_string(&snapshot()).expect("encode");
        assert!(!json.contains("desktopFull"));
    }
}
