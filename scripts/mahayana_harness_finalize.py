from pathlib import Path
import re

ROOT = Path("third_party/mahayana/mahayana-rs")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"missing anchor: {label}")


def patch_core() -> None:
    path = ROOT / "mahayana-harness/src/lib.rs"
    text = path.read_text()

    if "approved_once:" not in text:
        require(text, "    approved_tools: BTreeSet<String>,\n", "core approval field")
        require(text, "            approved_tools: BTreeSet::new(),\n", "core approval init")
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

    if "pub fn shares_state_with" not in text:
        anchor = "    pub fn register_service(&self, id: impl Into<String>) -> HarnessResult<()> {"
        require(text, anchor, "register_service")
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
            raise SystemExit(f"execute_tool approval block count={count}")

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
        require(text, old, "resolve_approval")
        text = text.replace(old, new, 1)

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
    assert!(matches!(
        harness.execute_tool(Some(&a.id), request()).await,
        Err(HarnessError::ApprovalRequired(_))
    ));

    let id = match harness.execute_tool(Some(&a.id), request()).await {
        Err(HarnessError::ApprovalRequired(id)) => id,
        other => panic!("expected approval request, got {other:?}"),
    };
    harness.resolve_approval(&id, ApprovalDecision::AcceptForSession).unwrap();
    assert!(harness.execute_tool(Some(&a.id), request()).await.is_ok());
    assert!(harness.execute_tool(Some(&a.id), request()).await.is_ok());
    assert!(matches!(
        harness.execute_tool(Some(&b.id), request()).await,
        Err(HarnessError::ApprovalRequired(_))
    ));
}

#[tokio::test]
async fn session_approval_requires_session() {
    let harness = MahayanaHarness::new(BuildProfile::DesktopFull);
    harness.register_tool(tool(), Arc::new(EchoHost)).unwrap();
    let id = match harness.execute_tool(None, request()).await {
        Err(HarnessError::ApprovalRequired(id)) => id,
        other => panic!("expected approval request, got {other:?}"),
    };
    assert!(matches!(
        harness.resolve_approval(&id, ApprovalDecision::AcceptForSession),
        Err(HarnessError::InvalidConfig(_))
    ));
}
''')


def patch_services_protocol() -> None:
    path = ROOT / "mahayana-harness-services/src/lib.rs"
    text = path.read_text().replace(
        "use std::collections::{BTreeMap, BTreeSet, VecDeque};",
        "use std::collections::{BTreeMap, VecDeque};",
    )
    if "pub fn list_schedules(&self)" not in text:
        marker = "    pub fn record_feedback(\n"
        require(text, marker, "record_feedback")
        methods = '''    pub fn list_schedules(&self) -> HarnessResult<Vec<ScheduleEntry>> {
        Ok(self.state()?.schedules.values().cloned().collect())
    }

    pub fn get_schedule(&self, schedule_id: &str) -> HarnessResult<ScheduleEntry> {
        self.state()?
            .schedules
            .get(schedule_id)
            .cloned()
            .ok_or_else(|| HarnessError::ServiceNotFound(format!("schedule:{schedule_id}")))
    }

    pub fn delete_schedule(&self, schedule_id: &str) -> HarnessResult<ScheduleEntry> {
        self.state()?
            .schedules
            .remove(schedule_id)
            .ok_or_else(|| HarnessError::ServiceNotFound(format!("schedule:{schedule_id}")))
    }

'''
        text = text.replace(marker, methods + marker, 1)
    path.write_text(text)

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
        if !harness.shares_state_with(services.harness()) {
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
        require(text, old, "HarnessApi::from_parts")
        text = text.replace(old, new, 1)

    if '"schedule.list"' not in text:
        marker = '            "feedback.record" => to_value(self.services.record_feedback(\n'
        require(text, marker, "protocol feedback")
        routes = '''            "schedule.list" => to_value(self.services.list_schedules()?),
            "schedule.get" => to_value(
                self.services
                    .get_schedule(required_str(&payload, "scheduleId")?)?,
            ),
            "schedule.delete" => to_value(
                self.services
                    .delete_schedule(required_str(&payload, "scheduleId")?)?,
            ),
'''
        text = text.replace(marker, routes + marker, 1)
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
    assert!(matches!(
        HarnessApi::from_parts(core, services),
        Err(HarnessError::InvalidConfig(_))
    ));
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
        let command = json!({
            "command": {
                "type": "automation.upsert",
                "requestId": format!("harness-schedule-upsert:{}:{}", id, now_ms()),
                "id": id.clone(),
                "name": format!("Harness schedule · {session_id}"),
                "prompt": instruction,
                "schedule": schedule.clone(),
                "trigger": {"kind": "schedule", "schedule": schedule},
                "enabled": true
            }
        });
        if let Err(error) = self.delegate("feature.execute", command) {
            let _ = self.execute_harness_state("schedule.delete", json!({"scheduleId": id}));
            return Err(error);
        }
        Ok(created)
    }

    fn harness_schedule_set_enabled(&self, payload: Value) -> Result<Value, AppHostError> {
        let id = required_string(&payload, "scheduleId")?;
        let enabled = payload
            .get("enabled")
            .and_then(Value::as_bool)
            .ok_or_else(|| AppHostError::InvalidRequest("enabled is required".into()))?;
        self.delegate(
            "feature.execute",
            json!({"command": {
                "type": "automation.setEnabled",
                "requestId": format!("harness-schedule-enabled:{}:{}", id, now_ms()),
                "id": id.clone(),
                "enabled": enabled
            }}),
        )?;
        self.execute_harness_state("schedule.setEnabled", payload)
    }

    fn harness_schedule_delete(&self, payload: Value) -> Result<Value, AppHostError> {
        let id = required_string(&payload, "scheduleId")?;
        self.delegate(
            "feature.execute",
            json!({"command": {
                "type": "automation.delete",
                "requestId": format!("harness-schedule-delete:{}:{}", id, now_ms()),
                "id": id.clone()
            }}),
        )?;
        self.execute_harness_state("schedule.delete", payload)
    }

    fn harness_schedule_run(&self, payload: Value) -> Result<Value, AppHostError> {
        let id = required_string(&payload, "scheduleId")?;
        let schedule = self.execute_harness_state(
            "schedule.get",
            json!({"scheduleId": id.clone()}),
        )?;
        let session_id = required_string(&schedule, "sessionId")?;
        let accepted = self.delegate(
            "feature.execute",
            json!({"command": {
                "type": "automation.run",
                "requestId": format!("harness-schedule-run:{}:{}", id, now_ms()),
                "id": id.clone()
            }}),
        )?;
        self.execute_harness_state(
            "session.appendEvent",
            json!({
                "sessionId": session_id,
                "kind": "schedule/run",
                "eventPayload": {"scheduleId": id, "accepted": accepted.clone()}
            }),
        )?;
        Ok(json!({"schedule": schedule, "accepted": accepted}))
    }
'''
        require(text, old, "UnifiedAppHost::execute_harness")
        text = text.replace(old, new, 1)

    if '| "schedule.delete"' not in text:
        old = '            | "schedule.setEnabled"\n            | "feedback.record"'
        require(text, old, "journal schedule")
        text = text.replace(
            old,
            '            | "schedule.setEnabled"\n            | "schedule.delete"\n            | "feedback.record"',
            1,
        )

    tail = text[text.index("fn is_journaled_operation"):]
    if '"interaction.permissionPreset.register"' not in tail:
        anchor = '            | "command.register"\n    )'
        require(text, anchor, "journal advanced tail")
        ops = [
            "interaction.permissionPreset.register",
            "interaction.permissionPreset.activate",
            "interaction.question.create",
            "interaction.question.answer",
            "agentPlan.enter",
            "agentPlan.exit",
            "bundle.register",
            "preset.register",
            "extension.register",
            "extension.setEnabled",
            "hook.register",
        ]
        extra = "".join(f'            | "{op}"\n' for op in ops)
        text = text.replace(anchor, '            | "command.register"\n' + extra + '    )', 1)

    path.write_text(text)


def patch_ci() -> None:
    path = Path(".github/workflows/mahayana-fast-checks.yml")
    text = path.read_text()
    if "-p mahayana-harness-advanced" not in text:
        anchor = "          -p mahayana-harness-services\n          -p mahayana-harness-adapters\n"
        require(text, anchor, "fast-check Harness package list")
        text = text.replace(
            anchor,
            "          -p mahayana-harness-services\n"
            "          -p mahayana-harness-advanced\n"
            "          -p mahayana-harness-adapters\n",
            1,
        )
    path.write_text(text)

    path = Path(".github/workflows/native-mobile.yml")
    text = path.read_text()
    old = "        run: cargo install cargo-ndk --locked\n"
    new = "        run: command -v cargo-ndk >/dev/null 2>&1 || cargo install cargo-ndk --locked\n"
    if old in text:
        text = text.replace(old, new, 1)
    elif new not in text:
        raise SystemExit("missing anchor: cargo-ndk install")
    path.write_text(text)


patch_core()
patch_services_protocol()
patch_unified_host()
patch_ci()
print("Mahayana Harness final source patch applied")
