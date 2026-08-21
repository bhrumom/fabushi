//! Mahayana-owned orchestration primitives.
//!
//! These provider-neutral state machines deliberately avoid Codex, Grok, or
//! model-vendor protocol types. Provider adapters translate into this kernel.

use serde::Deserialize;
use serde::Serialize;
use std::collections::HashMap;
use std::collections::HashSet;
use std::collections::VecDeque;

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PermissionMode {
    #[default]
    ReadOnly,
    Workspace,
    Elevated,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum RiskClass {
    ReadOnly,
    WorkspaceMutation,
    ExternalSideEffect,
    Privileged,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PermissionDisposition {
    Allow,
    Ask,
    Deny,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PermissionDecision {
    AllowOnce,
    AllowSession,
    DenyOnce,
    DenyAlways,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PermissionKey {
    pub capability: String,
    pub target: String,
}

impl PermissionKey {
    pub fn new(capability: impl Into<String>, target: impl Into<String>) -> Result<Self, KernelError> {
        let capability = capability.into();
        let target = target.into();
        if capability.trim().is_empty() {
            return Err(KernelError::EmptyField("capability"));
        }
        if target.trim().is_empty() {
            return Err(KernelError::EmptyField("target"));
        }
        Ok(Self { capability, target })
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PermissionRequest {
    pub key: PermissionKey,
    pub risk: RiskClass,
}

#[derive(Debug, Clone, Default)]
pub struct PermissionBook {
    session_allows: HashSet<PermissionKey>,
    permanent_denials: HashSet<PermissionKey>,
}

impl PermissionBook {
    pub fn evaluate(&self, mode: PermissionMode, request: &PermissionRequest) -> PermissionDisposition {
        if self.permanent_denials.contains(&request.key) {
            return PermissionDisposition::Deny;
        }
        if self.session_allows.contains(&request.key) {
            return PermissionDisposition::Allow;
        }
        match request.risk {
            RiskClass::ReadOnly => PermissionDisposition::Allow,
            RiskClass::WorkspaceMutation => match mode {
                PermissionMode::ReadOnly => PermissionDisposition::Deny,
                PermissionMode::Workspace | PermissionMode::Elevated => PermissionDisposition::Allow,
            },
            RiskClass::ExternalSideEffect | RiskClass::Privileged => PermissionDisposition::Ask,
        }
    }

    pub fn remember(&mut self, key: PermissionKey, decision: PermissionDecision) {
        match decision {
            PermissionDecision::AllowSession => {
                self.permanent_denials.remove(&key);
                self.session_allows.insert(key);
            }
            PermissionDecision::DenyAlways => {
                self.session_allows.remove(&key);
                self.permanent_denials.insert(key);
            }
            PermissionDecision::AllowOnce | PermissionDecision::DenyOnce => {}
        }
    }

    pub fn clear_session(&mut self) {
        self.session_allows.clear();
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum InputOrigin {
    User,
    Steer,
    Queued,
    Resume,
    Automation,
    Agent,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct InputEnvelope {
    pub id: String,
    pub text: String,
    pub origin: InputOrigin,
    pub created_at_ms: i64,
}

impl InputEnvelope {
    pub fn new(
        id: impl Into<String>,
        text: impl Into<String>,
        origin: InputOrigin,
        created_at_ms: i64,
    ) -> Result<Self, KernelError> {
        let id = id.into();
        let text = text.into();
        if id.trim().is_empty() {
            return Err(KernelError::EmptyField("input.id"));
        }
        if text.trim().is_empty() {
            return Err(KernelError::EmptyField("input.text"));
        }
        Ok(Self { id, text, origin, created_at_ms })
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct InputQueue(VecDeque<InputEnvelope>);

impl InputQueue {
    pub fn push(&mut self, input: InputEnvelope) {
        self.0.push_back(input);
    }

    pub fn steer(&mut self, input: InputEnvelope) {
        self.0.push_front(input);
    }

    pub fn pop(&mut self) -> Option<InputEnvelope> {
        self.0.pop_front()
    }

    pub fn len(&self) -> usize {
        self.0.len()
    }

    pub fn is_empty(&self) -> bool {
        self.0.is_empty()
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ContextWindow {
    pub id: String,
    pub generation: u64,
}

impl Default for ContextWindow {
    fn default() -> Self {
        Self::new()
    }
}

impl ContextWindow {
    pub fn new() -> Self {
        Self { id: uuid::Uuid::new_v4().to_string(), generation: 0 }
    }

    pub fn compact(&mut self) {
        self.id = uuid::Uuid::new_v4().to_string();
        self.generation = self.generation.saturating_add(1);
    }
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BackendCapabilities {
    pub realtime: bool,
    pub tools: bool,
    pub web: bool,
    pub mcp: bool,
    pub sandbox: bool,
    pub subagents: bool,
    pub checkpoints: bool,
    pub headless: bool,
    pub hooks: bool,
    pub skills: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TaskState {
    Planned,
    Running,
    Paused,
    Verifying,
    Succeeded,
    Failed,
    Cancelled,
}

impl TaskState {
    pub fn is_terminal(self) -> bool {
        matches!(self, Self::Succeeded | Self::Failed | Self::Cancelled)
    }
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum VerificationMode {
    BestEffort,
    #[default]
    ObjectiveRequired,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum VerificationKind {
    Test,
    CiCheck,
    Command,
    Artifact,
    HumanReview,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum OracleStatus {
    #[default]
    Pending,
    Passed,
    Failed,
    Skipped,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VerificationOracle {
    pub name: String,
    pub kind: VerificationKind,
    pub required: bool,
    pub objective: bool,
    pub status: OracleStatus,
    pub evidence: Option<String>,
}

impl VerificationOracle {
    pub fn new(
        name: impl Into<String>,
        kind: VerificationKind,
        required: bool,
        objective: bool,
    ) -> Result<Self, KernelError> {
        let name = name.into();
        if name.trim().is_empty() {
            return Err(KernelError::EmptyField("oracle.name"));
        }
        Ok(Self { name, kind, required, objective, status: OracleStatus::Pending, evidence: None })
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum AttemptOutcome {
    Running,
    Succeeded,
    Failed,
    Interrupted,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AttemptRecord {
    pub id: String,
    pub sequence: u32,
    pub fingerprint: String,
    pub started_at_ms: i64,
    pub ended_at_ms: Option<i64>,
    pub outcome: AttemptOutcome,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LoopPolicy {
    pub warn_after: u32,
    pub interrupt_after: u32,
}

impl Default for LoopPolicy {
    fn default() -> Self {
        Self { warn_after: 3, interrupt_after: 5 }
    }
}

impl LoopPolicy {
    pub fn validate(self) -> Result<Self, KernelError> {
        if self.warn_after < 2 || self.interrupt_after <= self.warn_after {
            return Err(KernelError::InvalidLoopPolicy);
        }
        Ok(self)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LoopObservation {
    Continue { repeats: u32 },
    Warn { repeats: u32 },
    Interrupt { repeats: u32 },
}

#[derive(Debug, Clone)]
struct LoopGuard {
    policy: LoopPolicy,
    last_fingerprint: Option<String>,
    repeats: u32,
}

impl LoopGuard {
    fn new(policy: LoopPolicy) -> Result<Self, KernelError> {
        Ok(Self { policy: policy.validate()?, last_fingerprint: None, repeats: 0 })
    }

    fn observe(&mut self, fingerprint: &str) -> LoopObservation {
        if self.last_fingerprint.as_deref() == Some(fingerprint) {
            self.repeats = self.repeats.saturating_add(1);
        } else {
            self.last_fingerprint = Some(fingerprint.to_string());
            self.repeats = 1;
        }
        if self.repeats >= self.policy.interrupt_after {
            LoopObservation::Interrupt { repeats: self.repeats }
        } else if self.repeats >= self.policy.warn_after {
            LoopObservation::Warn { repeats: self.repeats }
        } else {
            LoopObservation::Continue { repeats: self.repeats }
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TaskRecord {
    pub id: String,
    pub goal: String,
    pub state: TaskState,
    pub verification_mode: VerificationMode,
    pub oracles: Vec<VerificationOracle>,
    pub attempts: Vec<AttemptRecord>,
    pub queued_inputs: InputQueue,
    pub context_window: ContextWindow,
}

struct ManagedTask {
    record: TaskRecord,
    loop_guard: LoopGuard,
}

#[derive(Default)]
pub struct TaskSupervisor {
    tasks: HashMap<String, ManagedTask>,
}

impl TaskSupervisor {
    pub fn register_task(
        &mut self,
        id: impl Into<String>,
        goal: impl Into<String>,
        verification_mode: VerificationMode,
        loop_policy: LoopPolicy,
    ) -> Result<(), KernelError> {
        let id = id.into();
        let goal = goal.into();
        if id.trim().is_empty() {
            return Err(KernelError::EmptyField("task.id"));
        }
        if goal.trim().is_empty() {
            return Err(KernelError::EmptyField("task.goal"));
        }
        if self.tasks.contains_key(&id) {
            return Err(KernelError::DuplicateTask(id));
        }
        self.tasks.insert(
            id.clone(),
            ManagedTask {
                record: TaskRecord {
                    id,
                    goal,
                    state: TaskState::Planned,
                    verification_mode,
                    oracles: Vec::new(),
                    attempts: Vec::new(),
                    queued_inputs: InputQueue::default(),
                    context_window: ContextWindow::new(),
                },
                loop_guard: LoopGuard::new(loop_policy)?,
            },
        );
        Ok(())
    }

    pub fn task(&self, task_id: &str) -> Option<&TaskRecord> {
        self.tasks.get(task_id).map(|task| &task.record)
    }

    pub fn transition(&mut self, task_id: &str, next: TaskState) -> Result<(), KernelError> {
        let task = self.task_mut(task_id)?;
        if task.record.state == next {
            return Ok(());
        }
        if !valid_transition(task.record.state, next) {
            return Err(KernelError::InvalidTaskTransition {
                task_id: task_id.to_string(),
                from: task.record.state,
                to: next,
            });
        }
        if next == TaskState::Succeeded {
            ensure_completion_ready(&task.record)?;
        }
        task.record.state = next;
        Ok(())
    }

    pub fn add_oracle(&mut self, task_id: &str, oracle: VerificationOracle) -> Result<(), KernelError> {
        let task = self.task_mut(task_id)?;
        if task.record.oracles.iter().any(|existing| existing.name == oracle.name) {
            return Err(KernelError::DuplicateOracle(oracle.name));
        }
        task.record.oracles.push(oracle);
        Ok(())
    }

    pub fn record_oracle(
        &mut self,
        task_id: &str,
        name: &str,
        status: OracleStatus,
        evidence: Option<String>,
    ) -> Result<(), KernelError> {
        let task = self.task_mut(task_id)?;
        let oracle = task
            .record
            .oracles
            .iter_mut()
            .find(|oracle| oracle.name == name)
            .ok_or_else(|| KernelError::UnknownOracle(name.to_string()))?;
        oracle.status = status;
        oracle.evidence = evidence;
        Ok(())
    }

    pub fn queue_input(&mut self, task_id: &str, input: InputEnvelope) -> Result<(), KernelError> {
        self.task_mut(task_id)?.record.queued_inputs.push(input);
        Ok(())
    }

    pub fn steer(&mut self, task_id: &str, input: InputEnvelope) -> Result<(), KernelError> {
        self.task_mut(task_id)?.record.queued_inputs.steer(input);
        Ok(())
    }

    pub fn next_input(&mut self, task_id: &str) -> Result<Option<InputEnvelope>, KernelError> {
        Ok(self.task_mut(task_id)?.record.queued_inputs.pop())
    }

    pub fn compact_context(&mut self, task_id: &str) -> Result<ContextWindow, KernelError> {
        let task = self.task_mut(task_id)?;
        task.record.context_window.compact();
        Ok(task.record.context_window.clone())
    }

    pub fn begin_attempt(
        &mut self,
        task_id: &str,
        fingerprint: impl Into<String>,
        started_at_ms: i64,
    ) -> Result<LoopObservation, KernelError> {
        let fingerprint = fingerprint.into();
        if fingerprint.trim().is_empty() {
            return Err(KernelError::EmptyField("attempt.fingerprint"));
        }
        let task = self.task_mut(task_id)?;
        if task.record.state != TaskState::Running {
            return Err(KernelError::TaskNotRunning(task_id.to_string()));
        }
        let observation = task.loop_guard.observe(&fingerprint);
        if let LoopObservation::Interrupt { repeats } = observation {
            return Err(KernelError::RepeatedActionLoop {
                task_id: task_id.to_string(),
                fingerprint,
                repeats,
            });
        }
        let sequence = task.record.attempts.len().saturating_add(1) as u32;
        task.record.attempts.push(AttemptRecord {
            id: format!("attempt:{task_id}:{sequence}"),
            sequence,
            fingerprint,
            started_at_ms,
            ended_at_ms: None,
            outcome: AttemptOutcome::Running,
        });
        Ok(observation)
    }

    pub fn finish_attempt(
        &mut self,
        task_id: &str,
        attempt_id: &str,
        outcome: AttemptOutcome,
        ended_at_ms: i64,
    ) -> Result<(), KernelError> {
        if outcome == AttemptOutcome::Running {
            return Err(KernelError::AttemptOutcomeStillRunning);
        }
        let task = self.task_mut(task_id)?;
        let attempt = task
            .record
            .attempts
            .iter_mut()
            .find(|attempt| attempt.id == attempt_id)
            .ok_or_else(|| KernelError::UnknownAttempt(attempt_id.to_string()))?;
        attempt.outcome = outcome;
        attempt.ended_at_ms = Some(ended_at_ms);
        Ok(())
    }

    fn task_mut(&mut self, task_id: &str) -> Result<&mut ManagedTask, KernelError> {
        self.tasks.get_mut(task_id).ok_or_else(|| KernelError::UnknownTask(task_id.to_string()))
    }
}

fn valid_transition(from: TaskState, to: TaskState) -> bool {
    match from {
        TaskState::Planned => matches!(to, TaskState::Running | TaskState::Cancelled),
        TaskState::Running => matches!(
            to,
            TaskState::Paused | TaskState::Verifying | TaskState::Failed | TaskState::Cancelled
        ),
        TaskState::Paused => matches!(to, TaskState::Running | TaskState::Cancelled),
        TaskState::Verifying => matches!(
            to,
            TaskState::Running | TaskState::Succeeded | TaskState::Failed | TaskState::Cancelled
        ),
        TaskState::Succeeded | TaskState::Failed | TaskState::Cancelled => false,
    }
}

fn ensure_completion_ready(task: &TaskRecord) -> Result<(), KernelError> {
    let required: Vec<_> = task.oracles.iter().filter(|oracle| oracle.required).collect();
    if task.verification_mode == VerificationMode::ObjectiveRequired
        && !required.iter().any(|oracle| oracle.objective)
    {
        return Err(KernelError::MissingObjectiveOracle(task.id.clone()));
    }
    for oracle in required {
        match oracle.status {
            OracleStatus::Passed => {}
            OracleStatus::Failed => {
                return Err(KernelError::VerificationFailed {
                    task_id: task.id.clone(),
                    oracle: oracle.name.clone(),
                });
            }
            OracleStatus::Pending | OracleStatus::Skipped => {
                return Err(KernelError::VerificationIncomplete {
                    task_id: task.id.clone(),
                    oracle: oracle.name.clone(),
                });
            }
        }
    }
    Ok(())
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum KernelError {
    #[error("field must not be empty: {0}")]
    EmptyField(&'static str),
    #[error("invalid repeated-action loop policy")]
    InvalidLoopPolicy,
    #[error("task already exists: {0}")]
    DuplicateTask(String),
    #[error("task not found: {0}")]
    UnknownTask(String),
    #[error("task is not running: {0}")]
    TaskNotRunning(String),
    #[error("invalid task transition for {task_id}: {from:?} -> {to:?}")]
    InvalidTaskTransition { task_id: String, from: TaskState, to: TaskState },
    #[error("verification oracle already exists: {0}")]
    DuplicateOracle(String),
    #[error("verification oracle not found: {0}")]
    UnknownOracle(String),
    #[error("objective verification oracle is required before task completion: {0}")]
    MissingObjectiveOracle(String),
    #[error("verification is incomplete for {task_id}: {oracle}")]
    VerificationIncomplete { task_id: String, oracle: String },
    #[error("verification failed for {task_id}: {oracle}")]
    VerificationFailed { task_id: String, oracle: String },
    #[error("repeated action loop interrupted for {task_id} after {repeats} repeats: {fingerprint}")]
    RepeatedActionLoop { task_id: String, fingerprint: String, repeats: u32 },
    #[error("attempt not found: {0}")]
    UnknownAttempt(String),
    #[error("finished attempt cannot keep a running outcome")]
    AttemptOutcomeStillRunning,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn task() -> TaskSupervisor {
        let mut supervisor = TaskSupervisor::default();
        supervisor
            .register_task(
                "T01",
                "ship a verified change",
                VerificationMode::ObjectiveRequired,
                LoopPolicy { warn_after: 2, interrupt_after: 4 },
            )
            .expect("register task");
        supervisor
    }

    #[test]
    fn objective_oracle_gates_success() {
        let mut supervisor = task();
        supervisor
            .add_oracle(
                "T01",
                VerificationOracle::new("ci", VerificationKind::CiCheck, true, true).expect("oracle"),
            )
            .expect("add oracle");
        supervisor.transition("T01", TaskState::Running).expect("start");
        supervisor.transition("T01", TaskState::Verifying).expect("verify");
        assert!(matches!(
            supervisor.transition("T01", TaskState::Succeeded),
            Err(KernelError::VerificationIncomplete { .. })
        ));
        supervisor
            .record_oracle("T01", "ci", OracleStatus::Passed, Some("run:123".to_string()))
            .expect("record oracle");
        supervisor.transition("T01", TaskState::Succeeded).expect("complete");
        assert_eq!(supervisor.task("T01").expect("task").state, TaskState::Succeeded);
    }

    #[test]
    fn repeated_action_is_warned_then_interrupted() {
        let mut supervisor = task();
        supervisor.transition("T01", TaskState::Running).expect("start");
        assert_eq!(
            supervisor.begin_attempt("T01", "shell:status", 1),
            Ok(LoopObservation::Continue { repeats: 1 })
        );
        assert_eq!(
            supervisor.begin_attempt("T01", "shell:status", 2),
            Ok(LoopObservation::Warn { repeats: 2 })
        );
        assert_eq!(
            supervisor.begin_attempt("T01", "shell:status", 3),
            Ok(LoopObservation::Warn { repeats: 3 })
        );
        assert!(matches!(
            supervisor.begin_attempt("T01", "shell:status", 4),
            Err(KernelError::RepeatedActionLoop { repeats: 4, .. })
        ));
    }

    #[test]
    fn steer_input_precedes_queued_input_without_losing_origin() {
        let mut supervisor = task();
        supervisor
            .queue_input(
                "T01",
                InputEnvelope::new("q1", "after this", InputOrigin::Queued, 1).expect("queued input"),
            )
            .expect("queue");
        supervisor
            .steer(
                "T01",
                InputEnvelope::new("s1", "change direction", InputOrigin::Steer, 2).expect("steer input"),
            )
            .expect("steer");
        let first = supervisor.next_input("T01").expect("next").expect("first input");
        assert_eq!(first.id, "s1");
        assert_eq!(first.origin, InputOrigin::Steer);
        let second = supervisor.next_input("T01").expect("next").expect("second input");
        assert_eq!(second.id, "q1");
        assert_eq!(second.origin, InputOrigin::Queued);
    }

    #[test]
    fn permanent_denial_wins_over_permission_mode() {
        let key = PermissionKey::new("network.fetch", "example.test").expect("key");
        let request = PermissionRequest { key: key.clone(), risk: RiskClass::ExternalSideEffect };
        let mut book = PermissionBook::default();
        assert_eq!(book.evaluate(PermissionMode::Elevated, &request), PermissionDisposition::Ask);
        book.remember(key, PermissionDecision::DenyAlways);
        assert_eq!(book.evaluate(PermissionMode::Elevated, &request), PermissionDisposition::Deny);
    }

    #[test]
    fn compaction_rotates_context_window_identity() {
        let mut supervisor = task();
        let before = supervisor.task("T01").expect("task").context_window.clone();
        let after = supervisor.compact_context("T01").expect("compact");
        assert_ne!(before.id, after.id);
        assert_eq!(after.generation, before.generation + 1);
    }
}
