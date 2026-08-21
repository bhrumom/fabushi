from pathlib import Path
import re

ROOT = Path("third_party/mahayana/mahayana-rs")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"missing anchor: {label}")


def patch_core() -> None:
    path = ROOT / "mahayana-harness/src/lib.rs"
    text = path.read_text()

    if "\n    NotFound(String)," not in text:
        anchor = '    #[error("state mutex is poisoned")]\n    StatePoisoned,\n'
        require(text, anchor, "core error enum")
        text = text.replace(
            anchor,
            '''    #[error("not found: {0}")]
    NotFound(String),
    #[error("invalid request: {0}")]
    InvalidRequest(String),
    #[error("policy denied: {0}")]
    PolicyDenied(String),
    #[error("serialization failed: {0}")]
    Serialization(String),
    #[error("invalid state: {0}")]
    InvalidState(String),
''' + anchor,
            1,
        )

    if "approved_once:" not in text:
        require(text, "    approved_tools: BTreeSet<String>,\n", "approval field")
        require(text, "            approved_tools: BTreeSet::new(),\n", "approval init")
        text = text.replace(
            "    approved_tools: BTreeSet<String>,\n",
            "    approved_once: BTreeSet<(Option<String>, String)>,\n"
            "    approved_for_session: BTreeMap<String, BTreeSet<String>>,\n",
            1,
        )
        text = text.replace(
            "            approved_tools: BTreeSet::new(),\n",
            "            approved_once: BTreeSet::new(),\n"
            "            approved_for_session: BTreeMap::new(),\n",
            1,
        )

    if "impl Default for MahayanaHarness" not in text:
        anchor = "impl MahayanaHarness {\n"
        require(text, anchor, "harness impl")
        text = text.replace(
            anchor,
            '''impl Default for MahayanaHarness {
    fn default() -> Self {
        Self::new(BuildProfile::DesktopFull)
    }
}

''' + anchor,
            1,
        )

    if "pub fn shares_state_with" not in text:
        anchor = "    pub fn register_service(&self, name: impl Into<String>) -> HarnessResult<()> {"
        require(text, anchor, "register service")
        text = text.replace(
            anchor,
            "    pub fn shares_state_with(&self, other: &Self) -> bool {\n"
            "        Arc::ptr_eq(&self.state, &other.state)\n"
            "    }\n\n" + anchor,
            1,
        )

    if "state.approved_once.remove" not in text:
        pattern = re.compile(
            r"        let \(registered, interceptors, approved\) = \{\n.*?"
            r"        \};\n\n        if registered\.definition\.requires_approval",
            re.S,
        )
        replacement = '''        let (registered, interceptors, approved) = {
            let mut state = self.state()?;
            let registered = state
                .tools
                .get(&request.name)
                .cloned()
                .ok_or_else(|| HarnessError::ToolNotFound(request.name.clone()))?;
            let approved = if registered.definition.requires_approval
                && !registered.definition.read_only
            {
                let session_approved = session_id
                    .and_then(|id| state.approved_for_session.get(id))
                    .is_some_and(|tools| tools.contains(&request.name));
                let one_shot_approved = state.approved_once.remove(&(
                    session_id.map(ToOwned::to_owned),
                    request.name.clone(),
                ));
                session_approved || one_shot_approved
            } else {
                true
            };
            (registered, state.interceptors.clone(), approved)
        };

        if registered.definition.requires_approval'''
        text, count = pattern.subn(replacement, text, count=1)
        if count != 1:
            raise SystemExit(f"execute tool approval block count={count}")

    if "approved_for_session.entry" not in text:
        old = '''        let mut state = self.state()?;
        let approval = state
            .approvals
            .remove(approval_id)
            .ok_or_else(|| HarnessError::ApprovalNotFound(approval_id.into()))?;
        if matches!(
            decision,
            ApprovalDecision::Accept | ApprovalDecision::AcceptForSession
        ) {
            state.approved_tools.insert(approval.tool.clone());
        }
        drop(state);
'''
        new = '''        let mut state = self.state()?;
        let approval = state
            .approvals
            .get(approval_id)
            .cloned()
            .ok_or_else(|| HarnessError::ApprovalNotFound(approval_id.into()))?;
        match decision {
            ApprovalDecision::Accept => {
                state
                    .approved_once
                    .insert((approval.session_id.clone(), approval.tool.clone()));
            }
            ApprovalDecision::AcceptForSession => {
                let session_id = approval.session_id.clone().ok_or_else(|| {
                    HarnessError::InvalidConfig(
                        "AcceptForSession requires a session-scoped approval".into(),
                    )
                })?;
                state
                    .approved_for_session
                    .entry(session_id)
                    .or_default()
                    .insert(approval.tool.clone());
            }
            ApprovalDecision::Decline | ApprovalDecision::Cancel => {}
        }
        state.approvals.remove(approval_id);
        drop(state);
'''
        require(text, old, "resolve approval")
        text = text.replace(old, new, 1)

    if "pub fn sessions(&self)" not in text:
        anchor = "    pub fn snapshot(&self) -> HarnessResult<RuntimeSnapshot> {\n"
        require(text, anchor, "snapshot")
        text = text.replace(
            anchor,
            '''    pub fn sessions(&self) -> HarnessResult<Vec<SessionRecord>> {
        Ok(self.state()?.sessions.values().cloned().collect())
    }

''' + anchor,
            1,
        )

    path.write_text(text)

    test = ROOT / "mahayana-harness/tests/approval_scope.rs"
    test.parent.mkdir(parents=True, exist_ok=True)
    test.write_text(r'''use async_trait::async_trait;
use mahayana_core::{ApprovalDecision, BuildProfile};
use mahayana_harness::{HarnessError, MahayanaHarness, ToolDefinition};
use mahayana_tool_host::{ToolCapabilities, ToolError, ToolHost, ToolRequest, ToolResult};
use serde_json::{json, Value};
use std::sync::Arc;

struct EchoHost;

#[async_trait]
impl ToolHost for EchoHost {
    async fn execute(&self, request: ToolRequest) -> Result<ToolResult, ToolError> {
        Ok(ToolResult { content: request.arguments, is_error: false })
    }

    fn capabilities(&self) -> ToolCapabilities {
        ToolCapabilities::for_profile(BuildProfile::DesktopFull)
    }
}

fn tool() -> ToolDefinition {
    ToolDefinition {
        name: "guarded.write".into(),
        description: "approval scope test".into(),
        input_schema: Value::Null,
        read_only: false,
        requires_approval: true,
        tags: Vec::new(),
    }
}

fn request() -> ToolRequest {
    ToolRequest { name: "guarded.write".into(), arguments: json!({"value": 1}) }
}

#[tokio::test]
async fn approval_lifetimes_are_scoped() {
    let harness = MahayanaHarness::new(BuildProfile::DesktopFull);
    let a = harness.create_session("a").unwrap();
    let b = harness.create_session("b").unwrap();
    harness.register_tool(tool(), Arc::new(EchoHost)).unwrap();

    let id = match harness.execute_tool(Some(&a.id), request()).await {
        Err(HarnessError::ApprovalRequired(id)) => id,
        other => panic!("expected approval request, got {other:?}"),
    };
    harness.resolve_approval(&id, ApprovalDecision::Accept).unwrap();
    assert!(harness.execute_tool(Some(&a.id), request()).await.is_ok());
    assert!(matches!(harness.execute_tool(Some(&a.id), request()).await, Err(HarnessError::ApprovalRequired(_))));

    let id = match harness.execute_tool(Some(&a.id), request()).await {
        Err(HarnessError::ApprovalRequired(id)) => id,
        other => panic!("expected approval request, got {other:?}"),
    };
    harness.resolve_approval(&id, ApprovalDecision::AcceptForSession).unwrap();
    assert!(harness.execute_tool(Some(&a.id), request()).await.is_ok());
    assert!(harness.execute_tool(Some(&a.id), request()).await.is_ok());
    assert!(matches!(harness.execute_tool(Some(&b.id), request()).await, Err(HarnessError::ApprovalRequired(_))));
}

#[tokio::test]
async fn session_approval_requires_session() {
    let harness = MahayanaHarness::new(BuildProfile::DesktopFull);
    harness.register_tool(tool(), Arc::new(EchoHost)).unwrap();
    let id = match harness.execute_tool(None, request()).await {
        Err(HarnessError::ApprovalRequired(id)) => id,
        other => panic!("expected approval request, got {other:?}"),
    };
    assert!(matches!(harness.resolve_approval(&id, ApprovalDecision::AcceptForSession), Err(HarnessError::InvalidConfig(_))));
}
''')


def patch_services() -> None:
    path = ROOT / "mahayana-harness-services/src/lib.rs"
    text = path.read_text()
    text = text.replace("use mahayana_tool_host::{ToolRequest, ToolResult};", "use mahayana_tool_host::ToolResult;")
    text = text.replace("use std::collections::{BTreeMap, BTreeSet, VecDeque};", "use std::collections::{BTreeMap, VecDeque};")
    text = text.replace("use std::path::PathBuf;\n", "")
    text = text.replace(
        "    pub fn runtime_snapshot(&self) -> RuntimeSnapshot {\n        self.harness.snapshot()\n    }",
        "    pub fn runtime_snapshot(&self) -> HarnessResult<RuntimeSnapshot> {\n        self.harness.snapshot()\n    }",
    )

    if "pub fn snapshot(&self) -> HarnessResult<Value>" not in text:
        anchor = "    pub fn providers(&self) -> Arc<Mutex<ProviderSet>> {\n"
        require(text, anchor, "services providers")
        text = text.replace(
            anchor,
            '''    pub fn snapshot(&self) -> HarnessResult<Value> {
        let state = self.lock_state()?;
        Ok(serde_json::json!({
            "runtime": self.harness.snapshot()?,
            "promptSections": state.prompt_sections.values().cloned().collect::<Vec<_>>(),
            "workspaces": state.workspaces.values().cloned().collect::<Vec<_>>(),
            "settings": state.settings.values().cloned().collect::<Vec<_>>(),
            "attachments": state.attachments.values().cloned().collect::<Vec<_>>(),
            "spills": state.spills.values().cloned().collect::<Vec<_>>(),
            "todos": state.todos.values().cloned().collect::<Vec<_>>(),
            "plans": state.plans.values().cloned().collect::<Vec<_>>(),
            "schedules": state.schedules.values().cloned().collect::<Vec<_>>(),
            "feedback": state.feedback.values().cloned().collect::<Vec<_>>(),
            "identity": state.identity.clone(),
            "teams": state.teams.values().cloned().collect::<Vec<_>>(),
            "skills": state.skills.values().cloned().collect::<Vec<_>>(),
            "commands": state.commands.values().cloned().collect::<Vec<_>>(),
            "contextFragments": state.context_fragments.values().cloned().collect::<Vec<_>>()
        }))
    }

''' + anchor,
            1,
        )

    if "pub fn list_schedules(&self)" not in text:
        anchor = "    pub fn record_feedback(\n"
        require(text, anchor, "record feedback")
        text = text.replace(
            anchor,
            '''    pub fn list_schedules(&self) -> HarnessResult<Vec<ScheduleEntry>> {
        Ok(self.lock_state()?.schedules.values().cloned().collect())
    }

    pub fn get_schedule(&self, schedule_id: &str) -> HarnessResult<ScheduleEntry> {
        self.lock_state()?
            .schedules
            .get(schedule_id)
            .cloned()
            .ok_or_else(|| HarnessError::ServiceNotFound(format!("schedule:{schedule_id}")))
    }

    pub fn delete_schedule(&self, schedule_id: &str) -> HarnessResult<ScheduleEntry> {
        self.lock_state()?
            .schedules
            .remove(schedule_id)
            .ok_or_else(|| HarnessError::ServiceNotFound(format!("schedule:{schedule_id}")))
    }

''' + anchor,
            1,
        )

    text = text.replace(
        "    pub fn search_sessions(&self, query: &str) -> HarnessResult<Vec<SessionSearchHit>> {",
        "    pub fn search_sessions(&self, query: &str, limit: usize) -> HarnessResult<Vec<SessionSearchHit>> {",
    )
    start = text.find("    pub fn search_sessions(&self, query: &str, limit: usize)")
    if start != -1:
        end = text.find("    pub fn hash_bytes", start)
        block = text[start:end]
        if "hits.truncate(limit);" not in block:
            block = block.replace("        Ok(hits)\n", "        hits.truncate(limit);\n        Ok(hits)\n", 1)
            text = text[:start] + block + text[end:]

    text = text.replace('services.search_sessions("lotus").unwrap()', 'services.search_sessions("lotus", 20).unwrap()')
    text = text.replace("MahayanaHarness::new()", "MahayanaHarness::default()")
    path.write_text(text)


def patch_protocol() -> None:
    path = ROOT / "mahayana-harness-protocol/src/lib.rs"
    text = path.read_text()
    if "parts must share one MahayanaHarness runtime" not in text:
        old = '''    pub fn from_parts(harness: MahayanaHarness, services: HarnessServices) -> HarnessResult<Self> {
        Ok(Self {
            advanced: AdvancedHarnessServices::new(harness.clone()),
            harness,
            services,
        })
    }
'''
        new = '''    pub fn from_parts(harness: MahayanaHarness, services: HarnessServices) -> HarnessResult<Self> {
        if !harness.shares_state_with(&services.harness()) {
            return Err(HarnessError::InvalidConfig(
                "HarnessApi parts must share one MahayanaHarness runtime".into(),
            ));
        }
        Ok(Self {
            advanced: AdvancedHarnessServices::new(harness.clone()),
            harness,
            services,
        })
    }
'''
        require(text, old, "protocol from parts")
        text = text.replace(old, new, 1)

    if '"schedule.list"' not in text:
        anchor = '            "feedback.record" => to_value(self.services.record_feedback(\n'
        require(text, anchor, "feedback route")
        text = text.replace(
            anchor,
            '''            "schedule.list" => to_value(self.services.list_schedules()?),
            "schedule.get" => to_value(self.services.get_schedule(required_str(&payload, "scheduleId")?)?),
            "schedule.delete" => to_value(self.services.delete_schedule(required_str(&payload, "scheduleId")?)?),
''' + anchor,
            1,
        )
    path.write_text(text)

    test = ROOT / "mahayana-harness-protocol/tests/shared_runtime.rs"
    test.parent.mkdir(parents=True, exist_ok=True)
    test.write_text(r'''use mahayana_core::BuildProfile;
use mahayana_harness::{HarnessError, MahayanaHarness};
use mahayana_harness_protocol::HarnessApi;
use mahayana_harness_services::HarnessServices;

#[test]
fn from_parts_rejects_split_harness_state() {
    let core = MahayanaHarness::new(BuildProfile::DesktopFull);
    let services = HarnessServices::new(MahayanaHarness::new(BuildProfile::DesktopFull));
    assert!(matches!(HarnessApi::from_parts(core, services), Err(HarnessError::InvalidConfig(_))));
}
''')


def patch_unified_host() -> None:
    path = ROOT / "mahayana-unified-app-host/src/lib.rs"
    text = path.read_text()
    if "fn harness_schedule_create" not in text:
        old = '''    fn execute_harness(&self, operation: &str, payload: Value) -> Result<Value, AppHostError> {
        self.journal
            .lock()
            .map_err(|_| AppHostError::Operation("harness journal lock poisoned".into()))?
            .execute(&self.harness, operation, payload)
    }
'''
        new = '''    fn execute_harness(&self, operation: &str, payload: Value) -> Result<Value, AppHostError> {
        match operation {
            "schedule.create" => self.harness_schedule_create(payload),
            "schedule.setEnabled" => self.harness_schedule_set_enabled(payload),
            "schedule.delete" => self.harness_schedule_delete(payload),
            "schedule.run" => self.harness_schedule_run(payload),
            _ => self.execute_harness_state(operation, payload),
        }
    }

    fn execute_harness_state(&self, operation: &str, payload: Value) -> Result<Value, AppHostError> {
        self.journal
            .lock()
            .map_err(|_| AppHostError::Operation("harness journal lock poisoned".into()))?
            .execute(&self.harness, operation, payload)
    }

    fn harness_schedule_create(&self, payload: Value) -> Result<Value, AppHostError> {
        let created = self.execute_harness_state("schedule.create", payload)?;
        let id = required_string(&created, "id")?;
        let session_id = required_string(&created, "sessionId")?;
        let instruction = required_string(&created, "instruction")?;
        let schedule = required_string(&created, "schedule")?;
        let command = json!({"command": {
            "type": "automation.upsert",
            "requestId": format!("harness-schedule-upsert:{}:{}", id, now_ms()),
            "id": id.clone(),
            "name": format!("Harness schedule · {session_id}"),
            "prompt": instruction,
            "schedule": schedule.clone(),
            "trigger": {"kind": "schedule", "schedule": schedule},
            "enabled": true
        }});
        if let Err(error) = self.delegate("feature.execute", command) {
            let _ = self.execute_harness_state("schedule.delete", json!({"scheduleId": id}));
            return Err(error);
        }
        Ok(created)
    }

    fn harness_schedule_set_enabled(&self, payload: Value) -> Result<Value, AppHostError> {
        let id = required_string(&payload, "scheduleId")?;
        let enabled = payload.get("enabled").and_then(Value::as_bool)
            .ok_or_else(|| AppHostError::InvalidRequest("enabled is required".into()))?;
        self.delegate("feature.execute", json!({"command": {
            "type": "automation.setEnabled",
            "requestId": format!("harness-schedule-enabled:{}:{}", id, now_ms()),
            "id": id.clone(),
            "enabled": enabled
        }}))?;
        self.execute_harness_state("schedule.setEnabled", payload)
    }

    fn harness_schedule_delete(&self, payload: Value) -> Result<Value, AppHostError> {
        let id = required_string(&payload, "scheduleId")?;
        self.delegate("feature.execute", json!({"command": {
            "type": "automation.delete",
            "requestId": format!("harness-schedule-delete:{}:{}", id, now_ms()),
            "id": id.clone()
        }}))?;
        self.execute_harness_state("schedule.delete", payload)
    }

    fn harness_schedule_run(&self, payload: Value) -> Result<Value, AppHostError> {
        let id = required_string(&payload, "scheduleId")?;
        let schedule = self.execute_harness_state("schedule.get", json!({"scheduleId": id.clone()}))?;
        let session_id = required_string(&schedule, "sessionId")?;
        let accepted = self.delegate("feature.execute", json!({"command": {
            "type": "automation.run",
            "requestId": format!("harness-schedule-run:{}:{}", id, now_ms()),
            "id": id.clone()
        }}))?;
        self.execute_harness_state("session.appendEvent", json!({
            "sessionId": session_id,
            "kind": "schedule/run",
            "eventPayload": {"scheduleId": id, "accepted": accepted.clone()}
        }))?;
        Ok(json!({"schedule": schedule, "accepted": accepted}))
    }
'''
        require(text, old, "unified execute harness")
        text = text.replace(old, new, 1)

    if '| "schedule.delete"' not in text:
        old = '            | "schedule.setEnabled"\n            | "feedback.record"'
        require(text, old, "journal schedule")
        text = text.replace(old, '            | "schedule.setEnabled"\n            | "schedule.delete"\n            | "feedback.record"', 1)

    tail = text[text.index("fn is_journaled_operation"):]
    if '"interaction.permissionPreset.register"' not in tail:
        anchor = '            | "command.register"\n    )'
        require(text, anchor, "journal advanced")
        ops = [
            "interaction.permissionPreset.register", "interaction.permissionPreset.activate",
            "interaction.question.create", "interaction.question.answer",
            "agentPlan.enter", "agentPlan.exit", "bundle.register", "preset.register",
            "extension.register", "extension.setEnabled", "hook.register",
        ]
        extra = "".join(f'            | "{op}"\n' for op in ops)
        text = text.replace(anchor, '            | "command.register"\n' + extra + '    )', 1)
    path.write_text(text)


patch_core()
patch_services()
patch_protocol()
patch_unified_host()
print("Mahayana Harness current-API final source patch applied")
