//! Product services and capability seams for `mahayana-harness`.
//!
//! These services cover the non-loop portions of a full agent harness while
//! remaining independent from Electron/Swift/Kotlin presentation code.

use async_trait::async_trait;
use mahayana_harness::{HarnessError, HarnessResult, MahayanaHarness, RuntimeSnapshot};
use mahayana_tool_host::{ToolRequest, ToolResult};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::collections::{BTreeMap, BTreeSet, VecDeque};
use std::path::PathBuf;
use std::sync::{Arc, Mutex, MutexGuard};
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PromptSection {
    pub id: String,
    pub priority: i32,
    pub content: String,
    #[serde(default)]
    pub enabled: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WorkspaceRecord {
    pub id: String,
    pub name: String,
    pub root: PathBuf,
    #[serde(default)]
    pub instructions: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SettingRecord {
    pub key: String,
    pub value: Value,
    pub updated_at_ms: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CredentialReference {
    pub id: String,
    pub provider: String,
    pub label: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AttachmentRecord {
    pub id: String,
    pub sha256: String,
    pub size: u64,
    pub media_type: String,
    #[serde(default)]
    pub filename: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SpillRecord {
    pub id: String,
    pub sha256: String,
    pub size: u64,
    pub reason: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TodoItem {
    pub id: String,
    pub text: String,
    pub status: String,
    pub created_at_ms: i64,
    pub updated_at_ms: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlanState {
    pub session_id: String,
    pub mode: String,
    #[serde(default)]
    pub steps: Vec<String>,
    #[serde(default)]
    pub review_required: bool,
    pub updated_at_ms: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScheduleEntry {
    pub id: String,
    pub session_id: String,
    pub instruction: String,
    pub schedule: String,
    pub enabled: bool,
    pub created_at_ms: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FeedbackRecord {
    pub id: String,
    pub session_id: String,
    pub kind: String,
    pub text: String,
    pub created_at_ms: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct IdentityRecord {
    pub anonymous_id: String,
    #[serde(default)]
    pub account_id: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionSearchHit {
    pub session_id: String,
    pub title: String,
    pub score: u32,
    pub excerpt: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TeamMember {
    pub agent_id: String,
    pub role: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TeamTask {
    pub id: String,
    pub text: String,
    pub assignee_agent_id: Option<String>,
    pub status: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TeamMessage {
    pub id: String,
    pub from_agent_id: String,
    pub to_agent_id: Option<String>,
    pub text: String,
    pub created_at_ms: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentTeam {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub members: Vec<TeamMember>,
    #[serde(default)]
    pub tasks: Vec<TeamTask>,
    #[serde(default)]
    pub mailbox: Vec<TeamMessage>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GuardPolicy {
    pub repeat_window: usize,
    pub repeat_threshold: usize,
    pub tool_timeout_ms: u64,
}

impl Default for GuardPolicy {
    fn default() -> Self {
        Self {
            repeat_window: 8,
            repeat_threshold: 3,
            tool_timeout_ms: 120_000,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GuardObservation {
    pub tool: String,
    pub fingerprint: String,
    pub repeated: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SkillRecord {
    pub id: String,
    pub name: String,
    pub description: String,
    #[serde(default)]
    pub metadata: Value,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CommandRecord {
    pub id: String,
    pub description: String,
    #[serde(default)]
    pub input_schema: Value,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ContextFragment {
    pub id: String,
    pub source: String,
    pub content: String,
    pub priority: i32,
}

#[async_trait]
pub trait CredentialProvider: Send + Sync {
    fn id(&self) -> &str;
    async fn store(&self, label: &str, secret: &[u8]) -> HarnessResult<CredentialReference>;
    async fn resolve(&self, reference: &CredentialReference) -> HarnessResult<Vec<u8>>;
    async fn remove(&self, reference: &CredentialReference) -> HarnessResult<()>;
}

#[async_trait]
pub trait ContentStore: Send + Sync {
    async fn put(&self, bytes: &[u8]) -> HarnessResult<String>;
    async fn get(&self, content_id: &str) -> HarnessResult<Option<Vec<u8>>>;
}

#[async_trait]
pub trait ShellProvider: Send + Sync {
    async fn execute(&self, command: &str, cwd: Option<&str>) -> HarnessResult<ToolResult>;
}

#[async_trait]
pub trait TerminalProvider: Send + Sync {
    async fn open(&self, cwd: Option<&str>) -> HarnessResult<String>;
    async fn write(&self, terminal_id: &str, data: &[u8]) -> HarnessResult<()>;
    async fn read(&self, terminal_id: &str) -> HarnessResult<Vec<u8>>;
    async fn close(&self, terminal_id: &str) -> HarnessResult<()>;
}

#[async_trait]
pub trait FileSystemProvider: Send + Sync {
    async fn read(&self, path: &str) -> HarnessResult<Vec<u8>>;
    async fn write(&self, path: &str, bytes: &[u8]) -> HarnessResult<()>;
    async fn list(&self, path: &str) -> HarnessResult<Vec<String>>;
    async fn remove(&self, path: &str) -> HarnessResult<()>;
}

#[async_trait]
pub trait LspProvider: Send + Sync {
    async fn request(&self, language: &str, method: &str, params: Value) -> HarnessResult<Value>;
}

#[async_trait]
pub trait WebProvider: Send + Sync {
    async fn search(&self, query: &str) -> HarnessResult<Value>;
    async fn fetch(&self, url: &str) -> HarnessResult<Value>;
}

#[async_trait]
pub trait CodeRuntimeProvider: Send + Sync {
    async fn execute(&self, language: &str, source: &str, input: Value) -> HarnessResult<Value>;
}

#[async_trait]
pub trait CompactionProvider: Send + Sync {
    async fn compact(&self, session_id: &str, transcript: &str) -> HarnessResult<String>;
}

#[async_trait]
pub trait SubagentProvider: Send + Sync {
    async fn spawn(&self, preset: &str, instruction: &str) -> HarnessResult<String>;
    async fn resume(&self, subagent_id: &str, instruction: &str) -> HarnessResult<Value>;
    async fn stop(&self, subagent_id: &str) -> HarnessResult<()>;
}

#[async_trait]
pub trait WorkflowExecutor: Send + Sync {
    async fn run(&self, workflow_id: &str, input: Value) -> HarnessResult<Value>;
}

#[async_trait]
pub trait AcpProvider: Send + Sync {
    async fn handle(&self, method: &str, params: Value) -> HarnessResult<Value>;
}

#[async_trait]
pub trait CommandProvider: Send + Sync {
    async fn execute(&self, command: &str, input: Value) -> HarnessResult<Value>;
}

#[derive(Default)]
pub struct ProviderSet {
    pub credentials: Option<Arc<dyn CredentialProvider>>,
    pub content: Option<Arc<dyn ContentStore>>,
    pub shell: Option<Arc<dyn ShellProvider>>,
    pub terminal: Option<Arc<dyn TerminalProvider>>,
    pub filesystem: Option<Arc<dyn FileSystemProvider>>,
    pub lsp: Option<Arc<dyn LspProvider>>,
    pub web: Option<Arc<dyn WebProvider>>,
    pub code_runtime: Option<Arc<dyn CodeRuntimeProvider>>,
    pub compaction: Option<Arc<dyn CompactionProvider>>,
    pub subagent: Option<Arc<dyn SubagentProvider>>,
    pub workflow: Option<Arc<dyn WorkflowExecutor>>,
    pub acp: Option<Arc<dyn AcpProvider>>,
    pub commands: Option<Arc<dyn CommandProvider>>,
}

#[derive(Debug, Default)]
struct ServiceState {
    prompt_sections: BTreeMap<String, PromptSection>,
    workspaces: BTreeMap<String, WorkspaceRecord>,
    settings: BTreeMap<String, SettingRecord>,
    credential_refs: BTreeMap<String, CredentialReference>,
    attachments: BTreeMap<String, AttachmentRecord>,
    spills: BTreeMap<String, SpillRecord>,
    todos: BTreeMap<String, TodoItem>,
    plans: BTreeMap<String, PlanState>,
    schedules: BTreeMap<String, ScheduleEntry>,
    feedback: BTreeMap<String, FeedbackRecord>,
    identity: Option<IdentityRecord>,
    teams: BTreeMap<String, AgentTeam>,
    guard_policy: GuardPolicy,
    recent_tool_calls: VecDeque<(String, String)>,
    skills: BTreeMap<String, SkillRecord>,
    commands: BTreeMap<String, CommandRecord>,
    context: BTreeMap<String, ContextFragment>,
}

#[derive(Clone)]
pub struct HarnessServices {
    harness: MahayanaHarness,
    state: Arc<Mutex<ServiceState>>,
    providers: Arc<Mutex<ProviderSet>>,
}

impl HarnessServices {
    pub fn new(harness: MahayanaHarness) -> Self {
        Self {
            harness,
            state: Arc::new(Mutex::new(ServiceState::default())),
            providers: Arc::new(Mutex::new(ProviderSet::default())),
        }
    }

    pub fn harness(&self) -> &MahayanaHarness {
        &self.harness
    }

    pub fn set_providers(&self, providers: ProviderSet) -> HarnessResult<()> {
        *self.providers()? = providers;
        Ok(())
    }

    pub fn add_prompt_section(&self, section: PromptSection) -> HarnessResult<()> {
        let id = required(&section.id, "prompt section id")?;
        self.state()?.prompt_sections.insert(id, section);
        Ok(())
    }

    pub fn assembled_prompt(&self) -> HarnessResult<String> {
        let mut sections = self
            .state()?
            .prompt_sections
            .values()
            .filter(|section| section.enabled)
            .cloned()
            .collect::<Vec<_>>();
        sections.sort_by_key(|section| (section.priority, section.id.clone()));
        Ok(sections
            .into_iter()
            .map(|section| section.content)
            .collect::<Vec<_>>()
            .join("\n\n"))
    }

    pub fn register_workspace(&self, workspace: WorkspaceRecord) -> HarnessResult<()> {
        let id = required(&workspace.id, "workspace id")?;
        self.state()?.workspaces.insert(id, workspace);
        Ok(())
    }

    pub fn list_workspaces(&self) -> HarnessResult<Vec<WorkspaceRecord>> {
        Ok(self.state()?.workspaces.values().cloned().collect())
    }

    pub fn set_setting(
        &self,
        key: impl Into<String>,
        value: Value,
    ) -> HarnessResult<SettingRecord> {
        let key = required(&key.into(), "setting key")?;
        let record = SettingRecord {
            key: key.clone(),
            value,
            updated_at_ms: now_ms(),
        };
        self.state()?.settings.insert(key, record.clone());
        Ok(record)
    }

    pub fn get_setting(&self, key: &str) -> HarnessResult<Option<SettingRecord>> {
        Ok(self.state()?.settings.get(key).cloned())
    }

    pub async fn store_credential(
        &self,
        label: &str,
        secret: &[u8],
    ) -> HarnessResult<CredentialReference> {
        let provider = self
            .providers()?
            .credentials
            .clone()
            .ok_or_else(|| HarnessError::ServiceNotFound("credentials".into()))?;
        let reference = provider.store(label, secret).await?;
        self.state()?
            .credential_refs
            .insert(reference.id.clone(), reference.clone());
        Ok(reference)
    }

    pub async fn resolve_credential(&self, reference_id: &str) -> HarnessResult<Vec<u8>> {
        let reference = self
            .state()?
            .credential_refs
            .get(reference_id)
            .cloned()
            .ok_or_else(|| HarnessError::ServiceNotFound(format!("credential:{reference_id}")))?;
        let provider = self
            .providers()?
            .credentials
            .clone()
            .ok_or_else(|| HarnessError::ServiceNotFound("credentials".into()))?;
        provider.resolve(&reference).await
    }

    pub fn register_attachment(
        &self,
        bytes: &[u8],
        media_type: impl Into<String>,
        filename: Option<String>,
    ) -> HarnessResult<AttachmentRecord> {
        let sha256 = sha256(bytes);
        let record = AttachmentRecord {
            id: format!("attachment:{sha256}"),
            sha256,
            size: bytes.len() as u64,
            media_type: required(&media_type.into(), "media type")?,
            filename,
        };
        self.state()?
            .attachments
            .insert(record.id.clone(), record.clone());
        Ok(record)
    }

    pub fn register_spill(
        &self,
        bytes: &[u8],
        reason: impl Into<String>,
    ) -> HarnessResult<SpillRecord> {
        let sha256 = sha256(bytes);
        let record = SpillRecord {
            id: format!("spill:{sha256}"),
            sha256,
            size: bytes.len() as u64,
            reason: required(&reason.into(), "spill reason")?,
        };
        self.state()?
            .spills
            .insert(record.id.clone(), record.clone());
        Ok(record)
    }

    pub fn add_todo(&self, text: impl Into<String>) -> HarnessResult<TodoItem> {
        let now = now_ms();
        let todo = TodoItem {
            id: format!("todo:{}", Uuid::new_v4()),
            text: required(&text.into(), "todo")?,
            status: "pending".into(),
            created_at_ms: now,
            updated_at_ms: now,
        };
        self.state()?.todos.insert(todo.id.clone(), todo.clone());
        Ok(todo)
    }

    pub fn update_todo(&self, todo_id: &str, status: impl Into<String>) -> HarnessResult<TodoItem> {
        let mut state = self.state()?;
        let todo = state
            .todos
            .get_mut(todo_id)
            .ok_or_else(|| HarnessError::ServiceNotFound(format!("todo:{todo_id}")))?;
        todo.status = required(&status.into(), "todo status")?;
        todo.updated_at_ms = now_ms();
        Ok(todo.clone())
    }

    pub fn set_plan(
        &self,
        session_id: impl Into<String>,
        steps: Vec<String>,
        review_required: bool,
    ) -> HarnessResult<PlanState> {
        let session_id = required(&session_id.into(), "session id")?;
        let plan = PlanState {
            session_id: session_id.clone(),
            mode: "plan".into(),
            steps,
            review_required,
            updated_at_ms: now_ms(),
        };
        self.state()?.plans.insert(session_id, plan.clone());
        Ok(plan)
    }

    pub fn exit_plan(&self, session_id: &str, approved: bool) -> HarnessResult<PlanState> {
        let mut state = self.state()?;
        let plan = state
            .plans
            .get_mut(session_id)
            .ok_or_else(|| HarnessError::ServiceNotFound(format!("plan:{session_id}")))?;
        if plan.review_required && !approved {
            return Err(HarnessError::ApprovalRequired(format!("plan:{session_id}")));
        }
        plan.mode = "execution".into();
        plan.updated_at_ms = now_ms();
        Ok(plan.clone())
    }

    pub fn schedule(
        &self,
        session_id: impl Into<String>,
        instruction: impl Into<String>,
        schedule: impl Into<String>,
    ) -> HarnessResult<ScheduleEntry> {
        let entry = ScheduleEntry {
            id: format!("schedule:{}", Uuid::new_v4()),
            session_id: required(&session_id.into(), "session id")?,
            instruction: required(&instruction.into(), "instruction")?,
            schedule: required(&schedule.into(), "schedule")?,
            enabled: true,
            created_at_ms: now_ms(),
        };
        self.state()?
            .schedules
            .insert(entry.id.clone(), entry.clone());
        Ok(entry)
    }

    pub fn set_schedule_enabled(
        &self,
        schedule_id: &str,
        enabled: bool,
    ) -> HarnessResult<ScheduleEntry> {
        let mut state = self.state()?;
        let entry = state
            .schedules
            .get_mut(schedule_id)
            .ok_or_else(|| HarnessError::ServiceNotFound(format!("schedule:{schedule_id}")))?;
        entry.enabled = enabled;
        Ok(entry.clone())
    }

    pub fn record_feedback(
        &self,
        session_id: impl Into<String>,
        kind: impl Into<String>,
        text: impl Into<String>,
    ) -> HarnessResult<FeedbackRecord> {
        let record = FeedbackRecord {
            id: format!("feedback:{}", Uuid::new_v4()),
            session_id: required(&session_id.into(), "session id")?,
            kind: required(&kind.into(), "feedback kind")?,
            text: required(&text.into(), "feedback text")?,
            created_at_ms: now_ms(),
        };
        self.state()?
            .feedback
            .insert(record.id.clone(), record.clone());
        Ok(record)
    }

    pub fn identity(&self) -> HarnessResult<IdentityRecord> {
        let mut state = self.state()?;
        if let Some(identity) = state.identity.clone() {
            return Ok(identity);
        }
        let identity = IdentityRecord {
            anonymous_id: format!("anon:{}", Uuid::new_v4()),
            account_id: None,
        };
        state.identity = Some(identity.clone());
        Ok(identity)
    }

    pub fn bind_account(&self, account_id: impl Into<String>) -> HarnessResult<IdentityRecord> {
        let mut identity = self.identity()?;
        identity.account_id = Some(required(&account_id.into(), "account id")?);
        self.state()?.identity = Some(identity.clone());
        Ok(identity)
    }

    pub fn search_sessions(
        &self,
        query: &str,
        limit: usize,
    ) -> HarnessResult<Vec<SessionSearchHit>> {
        let query = query.trim().to_lowercase();
        if query.is_empty() {
            return Ok(Vec::new());
        }
        let snapshot: RuntimeSnapshot = self.harness.snapshot()?;
        let mut hits = Vec::new();
        for session in snapshot.sessions {
            let transcript = self.harness.transcript(&session.id)?;
            let haystack = format!("{}\n{}", session.title, transcript).to_lowercase();
            let score = haystack.matches(&query).count() as u32;
            if score == 0 {
                continue;
            }
            let excerpt = transcript
                .lines()
                .find(|line| line.to_lowercase().contains(&query))
                .unwrap_or(&session.title)
                .chars()
                .take(240)
                .collect();
            hits.push(SessionSearchHit {
                session_id: session.id,
                title: session.title,
                score,
                excerpt,
            });
        }
        hits.sort_by(|left, right| {
            right
                .score
                .cmp(&left.score)
                .then_with(|| left.session_id.cmp(&right.session_id))
        });
        hits.truncate(limit);
        Ok(hits)
    }

    pub fn create_team(
        &self,
        name: impl Into<String>,
        members: Vec<TeamMember>,
    ) -> HarnessResult<AgentTeam> {
        let team = AgentTeam {
            id: format!("team:{}", Uuid::new_v4()),
            name: required(&name.into(), "team name")?,
            members,
            tasks: Vec::new(),
            mailbox: Vec::new(),
        };
        self.state()?.teams.insert(team.id.clone(), team.clone());
        Ok(team)
    }

    pub fn add_team_task(
        &self,
        team_id: &str,
        text: impl Into<String>,
        assignee_agent_id: Option<String>,
    ) -> HarnessResult<TeamTask> {
        let mut state = self.state()?;
        let team = state
            .teams
            .get_mut(team_id)
            .ok_or_else(|| HarnessError::ServiceNotFound(format!("team:{team_id}")))?;
        let task = TeamTask {
            id: format!("team-task:{}", Uuid::new_v4()),
            text: required(&text.into(), "team task")?,
            assignee_agent_id,
            status: "pending".into(),
        };
        team.tasks.push(task.clone());
        Ok(task)
    }

    pub fn send_team_message(
        &self,
        team_id: &str,
        from_agent_id: impl Into<String>,
        to_agent_id: Option<String>,
        text: impl Into<String>,
    ) -> HarnessResult<TeamMessage> {
        let mut state = self.state()?;
        let team = state
            .teams
            .get_mut(team_id)
            .ok_or_else(|| HarnessError::ServiceNotFound(format!("team:{team_id}")))?;
        let message = TeamMessage {
            id: format!("team-message:{}", Uuid::new_v4()),
            from_agent_id: required(&from_agent_id.into(), "from agent")?,
            to_agent_id,
            text: required(&text.into(), "team message")?,
            created_at_ms: now_ms(),
        };
        team.mailbox.push(message.clone());
        Ok(message)
    }

    pub fn set_guard_policy(&self, policy: GuardPolicy) -> HarnessResult<()> {
        if policy.repeat_window == 0 || policy.repeat_threshold == 0 || policy.tool_timeout_ms == 0
        {
            return Err(HarnessError::InvalidConfig(
                "guard policy values must be positive".into(),
            ));
        }
        self.state()?.guard_policy = policy;
        Ok(())
    }

    pub fn observe_tool_call(&self, request: &ToolRequest) -> HarnessResult<GuardObservation> {
        let fingerprint = tool_fingerprint(request);
        let mut state = self.state()?;
        let policy = state.guard_policy.clone();
        let repeated_count = state
            .recent_tool_calls
            .iter()
            .filter(|(tool, hash)| tool == &request.name && hash == &fingerprint)
            .count();
        state
            .recent_tool_calls
            .push_back((request.name.clone(), fingerprint.clone()));
        while state.recent_tool_calls.len() > policy.repeat_window {
            state.recent_tool_calls.pop_front();
        }
        Ok(GuardObservation {
            tool: request.name.clone(),
            fingerprint,
            repeated: repeated_count + 1 >= policy.repeat_threshold,
        })
    }

    pub fn register_skill(&self, skill: SkillRecord) -> HarnessResult<()> {
        let id = required(&skill.id, "skill id")?;
        self.state()?.skills.insert(id, skill);
        Ok(())
    }

    pub fn register_command(&self, command: CommandRecord) -> HarnessResult<()> {
        let id = required(&command.id, "command id")?;
        self.state()?.commands.insert(id, command);
        Ok(())
    }

    pub fn inject_context(&self, fragment: ContextFragment) -> HarnessResult<()> {
        let id = required(&fragment.id, "context id")?;
        self.state()?.context.insert(id, fragment);
        Ok(())
    }

    pub fn assembled_context(&self) -> HarnessResult<Vec<ContextFragment>> {
        let mut fragments = self.state()?.context.values().cloned().collect::<Vec<_>>();
        fragments.sort_by_key(|fragment| (fragment.priority, fragment.id.clone()));
        Ok(fragments)
    }

    pub fn snapshot(&self) -> HarnessResult<Value> {
        let state = self.state()?;
        Ok(serde_json::json!({
            "promptSections": state.prompt_sections.values().collect::<Vec<_>>(),
            "workspaces": state.workspaces.values().collect::<Vec<_>>(),
            "settings": state.settings.values().collect::<Vec<_>>(),
            "credentialReferences": state.credential_refs.values().collect::<Vec<_>>(),
            "attachments": state.attachments.values().collect::<Vec<_>>(),
            "spills": state.spills.values().collect::<Vec<_>>(),
            "todos": state.todos.values().collect::<Vec<_>>(),
            "plans": state.plans.values().collect::<Vec<_>>(),
            "schedules": state.schedules.values().collect::<Vec<_>>(),
            "feedback": state.feedback.values().collect::<Vec<_>>(),
            "identity": state.identity,
            "teams": state.teams.values().collect::<Vec<_>>(),
            "guardPolicy": state.guard_policy,
            "skills": state.skills.values().collect::<Vec<_>>(),
            "commands": state.commands.values().collect::<Vec<_>>(),
            "context": state.context.values().collect::<Vec<_>>(),
        }))
    }

    fn state(&self) -> HarnessResult<MutexGuard<'_, ServiceState>> {
        self.state.lock().map_err(|_| HarnessError::StatePoisoned)
    }

    fn providers(&self) -> HarnessResult<MutexGuard<'_, ProviderSet>> {
        self.providers
            .lock()
            .map_err(|_| HarnessError::StatePoisoned)
    }
}

fn required(value: &str, field: &str) -> HarnessResult<String> {
    if value.trim().is_empty() {
        Err(HarnessError::InvalidConfig(format!(
            "{field} must not be empty"
        )))
    } else {
        Ok(value.to_string())
    }
}

fn sha256(bytes: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(bytes);
    format!("{:x}", hasher.finalize())
}

fn tool_fingerprint(request: &ToolRequest) -> String {
    let mut hasher = Sha256::new();
    hasher.update(request.name.as_bytes());
    if let Ok(bytes) = serde_json::to_vec(&request.arguments) {
        hasher.update(bytes);
    }
    format!("{:x}", hasher.finalize())
}

fn now_ms() -> i64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis().min(i64::MAX as u128) as i64)
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;
    use mahayana_core::BuildProfile;

    #[test]
    fn prompt_sections_are_ordered() {
        let services = HarnessServices::new(MahayanaHarness::new(BuildProfile::DesktopFull));
        services
            .add_prompt_section(PromptSection {
                id: "b".into(),
                priority: 20,
                content: "second".into(),
                enabled: true,
            })
            .unwrap();
        services
            .add_prompt_section(PromptSection {
                id: "a".into(),
                priority: 10,
                content: "first".into(),
                enabled: true,
            })
            .unwrap();
        assert_eq!(services.assembled_prompt().unwrap(), "first\n\nsecond");
    }

    #[test]
    fn session_search_uses_logged_transcript() {
        let harness = MahayanaHarness::new(BuildProfile::DesktopFull);
        let session = harness.create_session("alpha").unwrap();
        harness
            .append_session_event(
                &session.id,
                "user/message",
                serde_json::json!({"text": "searchable needle"}),
            )
            .unwrap();
        let services = HarnessServices::new(harness);
        let hits = services.search_sessions("needle", 10).unwrap();
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].session_id, session.id);
    }

    #[test]
    fn repeat_guard_detects_identical_calls() {
        let services = HarnessServices::new(MahayanaHarness::new(BuildProfile::DesktopFull));
        services
            .set_guard_policy(GuardPolicy {
                repeat_window: 4,
                repeat_threshold: 2,
                tool_timeout_ms: 1_000,
            })
            .unwrap();
        let request = ToolRequest {
            name: "read".into(),
            arguments: serde_json::json!({"path": "a"}),
        };
        assert!(!services.observe_tool_call(&request).unwrap().repeated);
        assert!(services.observe_tool_call(&request).unwrap().repeated);
    }
}
