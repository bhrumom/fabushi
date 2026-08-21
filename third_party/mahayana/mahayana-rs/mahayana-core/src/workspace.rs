//! Mahayana-owned workspace, checkpoint, rewind, and managed-worktree contracts.
//!
//! The kernel stores only product state and opaque snapshot references. Host
//! adapters own actual filesystem/Git capture and restore so Codex/Grok
//! implementations can be swapped without changing the public contract.

use serde::Deserialize;
use serde::Serialize;
use std::collections::BTreeMap;
use std::path::PathBuf;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SnapshotDomain {
    Filesystem,
    Git,
    Hunks,
    ToolState,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SnapshotRef {
    pub domain: SnapshotDomain,
    pub id: String,
    pub digest: Option<String>,
}

impl SnapshotRef {
    pub fn new(
        domain: SnapshotDomain,
        id: impl Into<String>,
        digest: Option<String>,
    ) -> Result<Self, WorkspaceError> {
        let id = id.into();
        if id.trim().is_empty() {
            return Err(WorkspaceError::EmptySnapshotId);
        }
        Ok(Self { domain, id, digest })
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WorkspaceCheckpoint {
    pub id: String,
    pub turn_index: u64,
    pub created_at_ms: i64,
    pub snapshots: Vec<SnapshotRef>,
}

impl WorkspaceCheckpoint {
    pub fn new(
        id: impl Into<String>,
        turn_index: u64,
        created_at_ms: i64,
        snapshots: Vec<SnapshotRef>,
    ) -> Result<Self, WorkspaceError> {
        let id = id.into();
        if id.trim().is_empty() {
            return Err(WorkspaceError::EmptyCheckpointId);
        }
        let mut seen = BTreeMap::new();
        for snapshot in &snapshots {
            if seen.insert(snapshot.domain as u8, ()).is_some() {
                return Err(WorkspaceError::DuplicateSnapshotDomain(snapshot.domain));
            }
        }
        Ok(Self {
            id,
            turn_index,
            created_at_ms,
            snapshots,
        })
    }

    pub fn snapshot(&self, domain: SnapshotDomain) -> Option<&SnapshotRef> {
        self.snapshots
            .iter()
            .find(|snapshot| snapshot.domain == domain)
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CheckpointStore {
    by_turn: BTreeMap<u64, WorkspaceCheckpoint>,
}

impl CheckpointStore {
    /// Last write wins for a turn so repeated turn-finalization remains
    /// idempotent while the checkpoint id still identifies the latest bundle.
    pub fn record(&mut self, checkpoint: WorkspaceCheckpoint) {
        self.by_turn.insert(checkpoint.turn_index, checkpoint);
    }

    pub fn get(&self, turn_index: u64) -> Option<&WorkspaceCheckpoint> {
        self.by_turn.get(&turn_index)
    }

    pub fn latest(&self) -> Option<&WorkspaceCheckpoint> {
        self.by_turn
            .last_key_value()
            .map(|(_, checkpoint)| checkpoint)
    }

    pub fn rewind_plan(&self, target_turn: u64) -> Result<RewindPlan, WorkspaceError> {
        let checkpoint = self
            .by_turn
            .get(&target_turn)
            .cloned()
            .ok_or(WorkspaceError::CheckpointNotFound(target_turn))?;
        Ok(RewindPlan {
            target_turn,
            checkpoint,
            discard_turns: self
                .by_turn
                .range(target_turn.saturating_add(1)..)
                .map(|(turn, _)| *turn)
                .collect(),
        })
    }

    /// Removes target and all future checkpoints after a successful restore to
    /// the start of `target_turn`, preventing stale future state from being
    /// reused after divergent execution.
    pub fn truncate_from(&mut self, target_turn: u64) -> Vec<WorkspaceCheckpoint> {
        let future = self.by_turn.split_off(&target_turn);
        future.into_values().collect()
    }

    pub fn len(&self) -> usize {
        self.by_turn.len()
    }

    pub fn is_empty(&self) -> bool {
        self.by_turn.is_empty()
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RewindPlan {
    pub target_turn: u64,
    pub checkpoint: WorkspaceCheckpoint,
    pub discard_turns: Vec<u64>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum WorktreeState {
    Creating,
    Ready,
    InUse,
    Paused,
    Removing,
    Removed,
    Failed,
}

impl WorktreeState {
    pub fn is_terminal(self) -> bool {
        matches!(self, Self::Removed | Self::Failed)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ManagedWorktree {
    pub id: String,
    pub root: PathBuf,
    pub repository_root: PathBuf,
    pub base_ref: String,
    pub branch: Option<String>,
    pub state: WorktreeState,
    pub dirty: bool,
    pub registered_by_mahayana: bool,
}

impl ManagedWorktree {
    pub fn validate(&self) -> Result<(), WorkspaceError> {
        if self.id.trim().is_empty() {
            return Err(WorkspaceError::EmptyWorktreeId);
        }
        if self.root.as_os_str().is_empty() || self.repository_root.as_os_str().is_empty() {
            return Err(WorkspaceError::EmptyWorktreePath);
        }
        if self.root == self.repository_root {
            return Err(WorkspaceError::RepositoryRootIsNotDisposable);
        }
        if self.base_ref.trim().is_empty() {
            return Err(WorkspaceError::EmptyBaseRef);
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WorktreeRemovalPolicy {
    pub allow_dirty: bool,
    pub require_mahayana_registration: bool,
}

impl Default for WorktreeRemovalPolicy {
    fn default() -> Self {
        Self {
            allow_dirty: false,
            require_mahayana_registration: true,
        }
    }
}

pub fn validate_worktree_removal(
    worktree: &ManagedWorktree,
    policy: WorktreeRemovalPolicy,
) -> Result<(), WorkspaceError> {
    worktree.validate()?;
    if worktree.state == WorktreeState::Removed {
        return Err(WorkspaceError::WorktreeAlreadyRemoved(worktree.id.clone()));
    }
    if policy.require_mahayana_registration && !worktree.registered_by_mahayana {
        return Err(WorkspaceError::UnmanagedWorktree(worktree.id.clone()));
    }
    if worktree.dirty && !policy.allow_dirty {
        return Err(WorkspaceError::DirtyWorktree(worktree.id.clone()));
    }
    Ok(())
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MutationRecord {
    pub turn_index: u64,
    pub path: PathBuf,
    pub operation: MutationKind,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum MutationKind {
    Create,
    Modify,
    Delete,
    Rename,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct MutationJournal(Vec<MutationRecord>);

impl MutationJournal {
    pub fn record(&mut self, mutation: MutationRecord) {
        self.0.push(mutation);
    }

    pub fn since(&self, turn_index: u64) -> Vec<&MutationRecord> {
        self.0
            .iter()
            .filter(|mutation| mutation.turn_index >= turn_index)
            .collect()
    }

    pub fn truncate_from(&mut self, turn_index: u64) {
        self.0.retain(|mutation| mutation.turn_index < turn_index);
    }
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum WorkspaceError {
    #[error("snapshot id must not be empty")]
    EmptySnapshotId,
    #[error("checkpoint id must not be empty")]
    EmptyCheckpointId,
    #[error("checkpoint contains duplicate snapshot domain: {0:?}")]
    DuplicateSnapshotDomain(SnapshotDomain),
    #[error("checkpoint not found for turn {0}")]
    CheckpointNotFound(u64),
    #[error("worktree id must not be empty")]
    EmptyWorktreeId,
    #[error("worktree paths must not be empty")]
    EmptyWorktreePath,
    #[error("repository root cannot be treated as a disposable worktree")]
    RepositoryRootIsNotDisposable,
    #[error("worktree base ref must not be empty")]
    EmptyBaseRef,
    #[error("worktree is already removed: {0}")]
    WorktreeAlreadyRemoved(String),
    #[error("refusing to remove unmanaged worktree: {0}")]
    UnmanagedWorktree(String),
    #[error("refusing to remove dirty worktree without explicit policy: {0}")]
    DirtyWorktree(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    fn snapshot(domain: SnapshotDomain, id: &str) -> SnapshotRef {
        SnapshotRef::new(domain, id, None).expect("snapshot")
    }

    #[test]
    fn rewind_plan_bundles_domains_and_discards_future_turns() {
        let mut store = CheckpointStore::default();
        for turn in 1..=3 {
            store.record(
                WorkspaceCheckpoint::new(
                    format!("checkpoint:{turn}"),
                    turn,
                    turn as i64,
                    vec![
                        snapshot(SnapshotDomain::Filesystem, &format!("fs:{turn}")),
                        snapshot(SnapshotDomain::Git, &format!("git:{turn}")),
                    ],
                )
                .expect("checkpoint"),
            );
        }
        let plan = store.rewind_plan(2).expect("rewind plan");
        assert_eq!(plan.target_turn, 2);
        assert_eq!(plan.discard_turns, vec![3]);
        assert_eq!(
            plan.checkpoint
                .snapshot(SnapshotDomain::Filesystem)
                .expect("fs")
                .id,
            "fs:2"
        );
        let removed = store.truncate_from(2);
        assert_eq!(removed.len(), 2);
        assert_eq!(store.len(), 1);
    }

    #[test]
    fn dirty_or_unmanaged_worktrees_fail_closed() {
        let worktree = ManagedWorktree {
            id: "wt:1".into(),
            root: "/repo/.mahayana/worktrees/1".into(),
            repository_root: "/repo".into(),
            base_ref: "main".into(),
            branch: Some("mahayana/task-1".into()),
            state: WorktreeState::Ready,
            dirty: true,
            registered_by_mahayana: true,
        };
        assert!(matches!(
            validate_worktree_removal(&worktree, WorktreeRemovalPolicy::default()),
            Err(WorkspaceError::DirtyWorktree(_))
        ));
        let unmanaged = ManagedWorktree {
            dirty: false,
            registered_by_mahayana: false,
            ..worktree
        };
        assert!(matches!(
            validate_worktree_removal(&unmanaged, WorktreeRemovalPolicy::default()),
            Err(WorkspaceError::UnmanagedWorktree(_))
        ));
    }

    #[test]
    fn duplicate_snapshot_domain_is_rejected() {
        let result = WorkspaceCheckpoint::new(
            "checkpoint:1",
            1,
            1,
            vec![
                snapshot(SnapshotDomain::Filesystem, "fs:a"),
                snapshot(SnapshotDomain::Filesystem, "fs:b"),
            ],
        );
        assert!(matches!(
            result,
            Err(WorkspaceError::DuplicateSnapshotDomain(
                SnapshotDomain::Filesystem
            ))
        ));
    }
}
