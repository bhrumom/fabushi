//! Product-owned orchestration loop shared by every Mahayana agent backend.
//!
//! Backends perform model/provider-specific turns. This layer owns task state,
//! backend selection, queue/steer semantics, attempt journals, verification,
//! context-window generation, and checkpoint metadata.

use crate::AgentBackend;
use crate::AgentError;
use crate::AgentMessageRequest;
use crate::BackendRegistry;
use crate::SharedAgentEventSink;
use crate::StartThreadRequest;
use mahayana_core::AgentThreadId;
use mahayana_core::ConversationId;
use mahayana_core::OperationId;
use mahayana_core::capability::kernel::AttemptOutcome;
use mahayana_core::capability::kernel::BackendCapabilities;
use mahayana_core::capability::kernel::InputEnvelope;
use mahayana_core::capability::kernel::KernelError;
use mahayana_core::capability::kernel::LoopObservation;
use mahayana_core::capability::kernel::LoopPolicy;
use mahayana_core::capability::kernel::OracleStatus;
use mahayana_core::capability::kernel::TaskRecord;
use mahayana_core::capability::kernel::TaskState;
use mahayana_core::capability::kernel::TaskSupervisor;
use mahayana_core::capability::kernel::VerificationMode;
use mahayana_core::capability::kernel::VerificationOracle;
use mahayana_core::capability::workspace::CheckpointStore;
use mahayana_core::capability::workspace::RewindPlan;
use mahayana_core::capability::workspace::WorkspaceCheckpoint;
use std::collections::HashMap;
use std::sync::Arc;
use std::sync::Mutex;

#[derive(Debug, Clone)]
pub struct SessionHandle {
    pub task_id: String,
    pub backend_id: String,
    pub conversation_id: ConversationId,
    pub thread_id: AgentThreadId,
}

struct SessionState {
    handle: SessionHandle,
    backend: Arc<dyn AgentBackend>,
}

/// One long-lived product orchestrator can host Codex, Grok-derived, local,
/// remote-model, or test backends simultaneously. Backend choice is based on
/// capability requirements and priority rather than hard-coded vendor names.
#[derive(Default)]
pub struct MahayanaAgentOrchestrator {
    backends: Mutex<BackendRegistry>,
    supervisor: Mutex<TaskSupervisor>,
    sessions: Mutex<HashMap<String, SessionState>>,
    checkpoints: Mutex<HashMap<String, CheckpointStore>>,
}

impl MahayanaAgentOrchestrator {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn register_backend(
        &self,
        id: impl Into<String>,
        priority: i32,
        backend: Arc<dyn AgentBackend>,
    ) -> Result<(), OrchestratorError> {
        lock(&self.backends)?.register(id, priority, backend)?;
        Ok(())
    }

    pub fn backend_descriptors(&self) -> Result<Vec<crate::BackendDescriptor>, OrchestratorError> {
        Ok(lock(&self.backends)?.descriptors())
    }

    pub async fn create_session(
        &self,
        task_id: impl Into<String>,
        goal: impl Into<String>,
        conversation_id: ConversationId,
        required: BackendCapabilities,
        verification_mode: VerificationMode,
        loop_policy: LoopPolicy,
    ) -> Result<SessionHandle, OrchestratorError> {
        let task_id = task_id.into();
        {
            let mut supervisor = lock(&self.supervisor)?;
            supervisor.register_task(task_id.clone(), goal, verification_mode, loop_policy)?;
        }
        let selected = lock(&self.backends)?
            .select(required)
            .ok_or(OrchestratorError::NoCompatibleBackend)?;
        let backend_id = lock(&self.backends)?
            .descriptors()
            .into_iter()
            .find(|descriptor| descriptor.implementation == selected.name())
            .map(|descriptor| descriptor.id)
            .unwrap_or_else(|| selected.name().to_string());
        let thread_id = selected
            .start_thread(StartThreadRequest {
                conversation_id: conversation_id.clone(),
            })
            .await?;
        let handle = SessionHandle {
            task_id: task_id.clone(),
            backend_id,
            conversation_id,
            thread_id,
        };
        lock(&self.sessions)?.insert(
            task_id.clone(),
            SessionState {
                handle: handle.clone(),
                backend: selected,
            },
        );
        lock(&self.checkpoints)?.insert(task_id, CheckpointStore::default());
        Ok(handle)
    }

    pub fn task(&self, task_id: &str) -> Result<Option<TaskRecord>, OrchestratorError> {
        Ok(lock(&self.supervisor)?.task(task_id).cloned())
    }

    pub fn add_oracle(
        &self,
        task_id: &str,
        oracle: VerificationOracle,
    ) -> Result<(), OrchestratorError> {
        lock(&self.supervisor)?.add_oracle(task_id, oracle)?;
        Ok(())
    }

    pub fn record_oracle(
        &self,
        task_id: &str,
        name: &str,
        status: OracleStatus,
        evidence: Option<String>,
    ) -> Result<(), OrchestratorError> {
        lock(&self.supervisor)?.record_oracle(task_id, name, status, evidence)?;
        Ok(())
    }

    pub fn queue_input(
        &self,
        task_id: &str,
        input: InputEnvelope,
    ) -> Result<(), OrchestratorError> {
        lock(&self.supervisor)?.queue_input(task_id, input)?;
        Ok(())
    }

    pub fn steer(&self, task_id: &str, input: InputEnvelope) -> Result<(), OrchestratorError> {
        lock(&self.supervisor)?.steer(task_id, input)?;
        Ok(())
    }

    pub fn next_input(&self, task_id: &str) -> Result<Option<InputEnvelope>, OrchestratorError> {
        Ok(lock(&self.supervisor)?.next_input(task_id)?)
    }

    pub fn pause(&self, task_id: &str) -> Result<(), OrchestratorError> {
        lock(&self.supervisor)?.transition(task_id, TaskState::Paused)?;
        Ok(())
    }

    pub fn resume(&self, task_id: &str) -> Result<(), OrchestratorError> {
        lock(&self.supervisor)?.transition(task_id, TaskState::Running)?;
        Ok(())
    }

    pub fn begin_verification(&self, task_id: &str) -> Result<(), OrchestratorError> {
        lock(&self.supervisor)?.transition(task_id, TaskState::Verifying)?;
        Ok(())
    }

    pub fn complete(&self, task_id: &str) -> Result<(), OrchestratorError> {
        lock(&self.supervisor)?.transition(task_id, TaskState::Succeeded)?;
        Ok(())
    }

    pub fn fail(&self, task_id: &str) -> Result<(), OrchestratorError> {
        let mut supervisor = lock(&self.supervisor)?;
        let state = supervisor
            .task(task_id)
            .ok_or_else(|| KernelError::UnknownTask(task_id.to_string()))?
            .state;
        if state == TaskState::Verifying {
            supervisor.transition(task_id, TaskState::Failed)?;
        } else if state == TaskState::Running {
            supervisor.transition(task_id, TaskState::Failed)?;
        } else {
            return Err(KernelError::InvalidTaskTransition {
                task_id: task_id.to_string(),
                from: state,
                to: TaskState::Failed,
            }
            .into());
        }
        Ok(())
    }

    pub fn record_checkpoint(
        &self,
        task_id: &str,
        checkpoint: WorkspaceCheckpoint,
    ) -> Result<(), OrchestratorError> {
        let mut stores = lock(&self.checkpoints)?;
        let store = stores
            .get_mut(task_id)
            .ok_or_else(|| OrchestratorError::SessionNotFound(task_id.to_string()))?;
        store.record(checkpoint);
        Ok(())
    }

    pub fn rewind_plan(
        &self,
        task_id: &str,
        target_turn: u64,
    ) -> Result<RewindPlan, OrchestratorError> {
        let stores = lock(&self.checkpoints)?;
        let store = stores
            .get(task_id)
            .ok_or_else(|| OrchestratorError::SessionNotFound(task_id.to_string()))?;
        Ok(store.rewind_plan(target_turn)?)
    }

    pub fn commit_rewind(&self, task_id: &str, target_turn: u64) -> Result<(), OrchestratorError> {
        let mut stores = lock(&self.checkpoints)?;
        let store = stores
            .get_mut(task_id)
            .ok_or_else(|| OrchestratorError::SessionNotFound(task_id.to_string()))?;
        store.truncate_from(target_turn);
        lock(&self.supervisor)?.compact_context(task_id)?;
        Ok(())
    }

    pub async fn send(
        &self,
        task_id: &str,
        operation_id: OperationId,
        text: String,
        client_message_id: Option<String>,
        fingerprint: String,
        started_at_ms: i64,
        events: SharedAgentEventSink,
    ) -> Result<LoopObservation, OrchestratorError> {
        let (handle, backend) = {
            let sessions = lock(&self.sessions)?;
            let session = sessions
                .get(task_id)
                .ok_or_else(|| OrchestratorError::SessionNotFound(task_id.to_string()))?;
            (session.handle.clone(), Arc::clone(&session.backend))
        };
        {
            let mut supervisor = lock(&self.supervisor)?;
            let state = supervisor
                .task(task_id)
                .ok_or_else(|| KernelError::UnknownTask(task_id.to_string()))?
                .state;
            if state == TaskState::Planned || state == TaskState::Paused {
                supervisor.transition(task_id, TaskState::Running)?;
            }
        }
        let observation =
            lock(&self.supervisor)?.begin_attempt(task_id, fingerprint, started_at_ms)?;
        let attempt_id = lock(&self.supervisor)?
            .task(task_id)
            .and_then(|task| task.attempts.last())
            .map(|attempt| attempt.id.clone())
            .ok_or_else(|| OrchestratorError::AttemptMissing(task_id.to_string()))?;

        let result = backend
            .send_message(
                AgentMessageRequest {
                    thread_id: handle.thread_id,
                    conversation_id: handle.conversation_id,
                    operation_id,
                    text,
                    client_message_id,
                },
                events,
            )
            .await;
        let ended_at_ms = now_ms();
        match result {
            Ok(()) => {
                lock(&self.supervisor)?.finish_attempt(
                    task_id,
                    &attempt_id,
                    AttemptOutcome::Succeeded,
                    ended_at_ms,
                )?;
                Ok(observation)
            }
            Err(error) => {
                lock(&self.supervisor)?.finish_attempt(
                    task_id,
                    &attempt_id,
                    AttemptOutcome::Failed,
                    ended_at_ms,
                )?;
                Err(error.into())
            }
        }
    }

    pub async fn interrupt(
        &self,
        task_id: &str,
        operation_id: &OperationId,
    ) -> Result<(), OrchestratorError> {
        let backend = {
            let sessions = lock(&self.sessions)?;
            Arc::clone(
                &sessions
                    .get(task_id)
                    .ok_or_else(|| OrchestratorError::SessionNotFound(task_id.to_string()))?
                    .backend,
            )
        };
        backend.interrupt(operation_id).await?;
        Ok(())
    }
}

fn lock<T>(mutex: &Mutex<T>) -> Result<std::sync::MutexGuard<'_, T>, OrchestratorError> {
    mutex.lock().map_err(|_| OrchestratorError::LockPoisoned)
}

fn now_ms() -> i64 {
    use std::time::SystemTime;
    use std::time::UNIX_EPOCH;
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
        .try_into()
        .unwrap_or(i64::MAX)
}

#[derive(Debug, thiserror::Error)]
pub enum OrchestratorError {
    #[error(transparent)]
    Agent(#[from] AgentError),
    #[error(transparent)]
    Kernel(#[from] KernelError),
    #[error(transparent)]
    Workspace(#[from] mahayana_core::capability::workspace::WorkspaceError),
    #[error("no registered backend satisfies the requested capabilities")]
    NoCompatibleBackend,
    #[error("orchestrated session was not found: {0}")]
    SessionNotFound(String),
    #[error("attempt was not recorded for task: {0}")]
    AttemptMissing(String),
    #[error("orchestrator state lock was poisoned")]
    LockPoisoned,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::AgentEvent;
    use crate::AgentEventSink;
    use crate::ApprovalResolution;
    use async_trait::async_trait;
    use mahayana_core::Message;
    use mahayana_core::MessageId;
    use mahayana_core::MessageRole;
    use mahayana_core::capability::kernel::VerificationKind;
    use std::sync::Mutex as StdMutex;

    struct EchoBackend;

    #[async_trait]
    impl AgentBackend for EchoBackend {
        async fn start_thread(
            &self,
            _request: StartThreadRequest,
        ) -> Result<AgentThreadId, AgentError> {
            AgentThreadId::new("thread:echo")
                .map_err(|error| AgentError::Backend(error.to_string()))
        }

        async fn send_message(
            &self,
            request: AgentMessageRequest,
            events: SharedAgentEventSink,
        ) -> Result<(), AgentError> {
            events.emit(AgentEvent::MessageCompleted {
                message: Message {
                    id: MessageId::generated("message"),
                    conversation_id: request.conversation_id,
                    role: MessageRole::Assistant,
                    text: request.text,
                    created_at_ms: 1,
                    metadata: serde_json::Value::Null,
                },
            })
        }

        async fn interrupt(&self, _operation_id: &OperationId) -> Result<(), AgentError> {
            Ok(())
        }

        async fn resolve_approval(
            &self,
            _resolution: ApprovalResolution,
        ) -> Result<(), AgentError> {
            Ok(())
        }

        fn capabilities(&self) -> BackendCapabilities {
            BackendCapabilities {
                tools: true,
                sandbox: true,
                headless: true,
                ..BackendCapabilities::default()
            }
        }

        fn name(&self) -> &'static str {
            "echo"
        }
    }

    struct Sink(StdMutex<Vec<String>>);

    impl AgentEventSink for Sink {
        fn emit(&self, event: AgentEvent) -> Result<(), AgentError> {
            if let AgentEvent::MessageCompleted { message } = event {
                self.0
                    .lock()
                    .map_err(|_| AgentError::Backend("sink poisoned".into()))?
                    .push(message.text);
            }
            Ok(())
        }
    }

    #[tokio::test]
    async fn non_vendor_orchestrator_runs_and_requires_objective_verification() {
        let orchestrator = MahayanaAgentOrchestrator::new();
        orchestrator
            .register_backend("local-echo", 10, Arc::new(EchoBackend))
            .expect("register backend");
        orchestrator
            .create_session(
                "T01",
                "finish work",
                ConversationId("mahayana:agent:assistant".into()),
                BackendCapabilities {
                    tools: true,
                    sandbox: true,
                    ..BackendCapabilities::default()
                },
                VerificationMode::ObjectiveRequired,
                LoopPolicy::default(),
            )
            .await
            .expect("create session");
        orchestrator
            .add_oracle(
                "T01",
                VerificationOracle::new("ci", VerificationKind::CiCheck, true, true)
                    .expect("oracle"),
            )
            .expect("add oracle");
        let sink = Arc::new(Sink(StdMutex::new(Vec::new())));
        orchestrator
            .send(
                "T01",
                OperationId::generated("operation"),
                "hello".into(),
                None,
                "turn:hello".into(),
                1,
                sink.clone(),
            )
            .await
            .expect("send");
        orchestrator.begin_verification("T01").expect("verify");
        assert!(orchestrator.complete("T01").is_err());
        orchestrator
            .record_oracle("T01", "ci", OracleStatus::Passed, Some("run:1".into()))
            .expect("record oracle");
        orchestrator.complete("T01").expect("complete");
        assert_eq!(
            orchestrator
                .task("T01")
                .expect("task")
                .expect("record")
                .state,
            TaskState::Succeeded
        );
        assert_eq!(sink.0.lock().expect("sink").as_slice(), ["hello"]);
    }
}
