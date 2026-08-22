from pathlib import Path
import re

root = Path("third_party/mahayana/mahayana-rs")

# Reconcile the stable JSON protocol with the current HarnessServices API.
path = root / "mahayana-harness-protocol/src/lib.rs"
text = path.read_text()
text = text.replace(
    "    CommandRecord, ContextFragment, HarnessServices, PromptSection, SkillRecord, TeamMember,\n    WorkspaceRecord,\n",
    "    CommandRecord, ContextFragment, HarnessServices, PromptSection, SkillRecord, TeamMember,\n",
)
text = text.replace(".add_prompt_section(from_payload::<PromptSection>(payload)?)?", ".register_prompt_section(from_payload::<PromptSection>(payload)?)?")
text = text.replace(
    '"prompt.assemble" => Ok(json!({"prompt": self.services.assembled_prompt()?})),',
    '"prompt.assemble" => Ok(json!({"prompt": self.services.assemble_prompt(optional_str(&payload, "base").unwrap_or(""))?})),',
)
text = text.replace('"context.list" => to_value(self.services.assembled_context()?),', '"context.list" => to_value(self.services.context_fragments()?),')

replacements = [
('''            "workspace.register" => {
                self.services
                    .register_workspace(from_payload::<WorkspaceRecord>(payload)?)?;
                Ok(Value::Null)
            }
            "workspace.list" => to_value(self.services.list_workspaces()?),
''', '''            "workspace.register" => to_value(self.services.register_workspace(
                required_string(&payload, "root")?,
                required_string(&payload, "label")?,
            )?),
            "workspace.list" => to_value(self.services.workspaces()?),
'''),
('''            "todo.update" => to_value(self.services.update_todo(
                required_str(&payload, "todoId")?,
                required_string(&payload, "status")?,
            )?),
''', '''            "todo.update" => to_value(self.services.update_todo(
                required_str(&payload, "todoId")?,
                todo_done(&payload)?,
            )?),
'''),
('''            "feedback.record" => to_value(self.services.record_feedback(
                required_string(&payload, "sessionId")?,
                required_string(&payload, "kind")?,
                required_string(&payload, "text")?,
            )?),
''', '''            "feedback.record" => to_value(self.services.record_feedback(
                optional_string(&payload, "sessionId"),
                optional_i32(&payload, "rating"),
                optional_string(&payload, "note").or_else(|| optional_string(&payload, "text")),
            )?),
'''),
('''            "identity.bindAccount" => to_value(
                self.services
                    .bind_account(required_string(&payload, "accountId")?)?,
            ),
''', '''            "identity.bindAccount" => to_value(self.services.bind_identity_account(
                Some(required_string(&payload, "accountId")?),
                optional_string(&payload, "displayName"),
            )?),
'''),
('''            "team.addTask" => to_value(self.services.add_team_task(
                required_str(&payload, "teamId")?,
                required_string(&payload, "text")?,
                optional_string(&payload, "assigneeAgentId"),
            )?),
''', '''            "team.addTask" => to_value(self.services.add_team_task(
                required_str(&payload, "teamId")?,
                optional_string(&payload, "assigneeAgentId").unwrap_or_else(|| "unassigned".into()),
                required_string(&payload, "text")?,
            )?),
'''),
('''            "team.sendMessage" => to_value(self.services.send_team_message(
                required_str(&payload, "teamId")?,
                required_string(&payload, "fromAgentId")?,
                optional_string(&payload, "toAgentId"),
                required_string(&payload, "text")?,
            )?),
''', '''            "team.sendMessage" => to_value(self.services.send_team_message(
                required_str(&payload, "teamId")?,
                required_string(&payload, "fromAgentId")?,
                optional_string(&payload, "toAgentId"),
                payload.get("message").cloned().unwrap_or(Value::String(required_string(&payload, "text")?)),
            )?),
'''),
]
for old, new in replacements:
    if old in text:
        text = text.replace(old, new, 1)

if "fn todo_done(payload: &Value)" not in text:
    anchor = "fn optional_usize(payload: &Value, key: &str) -> Option<usize> {\n"
    if anchor not in text:
        raise SystemExit("missing protocol helper anchor")
    helpers = '''fn todo_done(payload: &Value) -> HarnessResult<bool> {
    if let Some(done) = payload.get("done").and_then(Value::as_bool) {
        return Ok(done);
    }
    match required_str(payload, "status")? {
        "done" | "completed" | "complete" => Ok(true),
        "pending" | "open" | "todo" => Ok(false),
        status => Err(HarnessError::InvalidConfig(format!("unsupported todo status: {status}"))),
    }
}

fn optional_i32(payload: &Value, key: &str) -> Option<i32> {
    payload
        .get(key)
        .and_then(Value::as_i64)
        .and_then(|value| i32::try_from(value).ok())
}

'''
    text = text.replace(anchor, helpers + anchor, 1)
path.write_text(text)

# Reconcile ToolHost adapters with the request-object provider traits.
path = root / "mahayana-harness-adapters/src/lib.rs"
text = path.read_text()
text = text.replace(
    '''use mahayana_harness_services::{
    CodeRuntimeProvider, CommandProvider, ContentStore, FileSystemProvider, LspProvider,
    ShellProvider, WebProvider,
};''',
    '''use mahayana_harness_services::{
    CodeRuntimeProvider, CodeRuntimeRequest, CommandProvider, ContentStore, FileSystemProvider,
    FileSystemRequest, LspProvider, LspRequest, ShellProvider, ShellRequest, WebProvider, WebRequest,
};''',
)
pattern = re.compile(r"#\[async_trait\]\nimpl ShellProvider for ToolHostAdapters \{.*?\n\}\n\n#\[derive\(Default\)\]\npub struct MemoryContentStore", re.S)
replacement = r'''#[async_trait]
impl ShellProvider for ToolHostAdapters {
    async fn run(&self, request: ShellRequest) -> HarnessResult<ToolResult> {
        self.invoke(
            &self.routes.shell,
            json!({"command": request.command, "cwd": request.cwd, "env": request.env}),
        )
        .await
    }
}

#[async_trait]
impl FileSystemProvider for ToolHostAdapters {
    async fn perform(&self, request: FileSystemRequest) -> HarnessResult<Value> {
        let route = match request.operation.as_str() {
            "read" => &self.routes.fs_read,
            "write" => &self.routes.fs_write,
            "list" => &self.routes.fs_list,
            "remove" | "delete" => &self.routes.fs_remove,
            operation => {
                return Err(HarnessError::InvalidConfig(format!(
                    "unsupported filesystem operation: {operation}"
                )))
            }
        };
        self.invoke_value(
            route,
            json!({
                "operation": request.operation,
                "path": request.path,
                "destination": request.destination,
                "content": request.content,
            }),
        )
        .await
    }
}

#[async_trait]
impl LspProvider for ToolHostAdapters {
    async fn perform(&self, request: LspRequest) -> HarnessResult<Value> {
        self.invoke_value(
            &self.routes.lsp,
            json!({
                "operation": request.operation,
                "language": request.language,
                "path": request.path,
                "position": request.position,
                "query": request.query,
            }),
        )
        .await
    }
}

#[async_trait]
impl WebProvider for ToolHostAdapters {
    async fn perform(&self, request: WebRequest) -> HarnessResult<Value> {
        let route = match request.operation.as_str() {
            "search" => &self.routes.web_search,
            "fetch" | "open" => &self.routes.web_fetch,
            operation => {
                return Err(HarnessError::InvalidConfig(format!(
                    "unsupported web operation: {operation}"
                )))
            }
        };
        self.invoke_value(
            route,
            json!({
                "operation": request.operation,
                "query": request.query,
                "url": request.url,
                "options": request.options,
            }),
        )
        .await
    }
}

#[async_trait]
impl CodeRuntimeProvider for ToolHostAdapters {
    async fn run(&self, request: CodeRuntimeRequest) -> HarnessResult<Value> {
        self.invoke_value(
            &self.routes.code_execute,
            json!({
                "language": request.language,
                "code": request.code,
                "cwd": request.cwd,
            }),
        )
        .await
    }
}

#[async_trait]
impl CommandProvider for ToolHostAdapters {
    async fn invoke(&self, name: &str, arguments: Value) -> HarnessResult<Value> {
        self.invoke_value(
            &self.routes.command_execute,
            json!({"command": name, "arguments": arguments}),
        )
        .await
    }
}

#[derive(Default)]
pub struct MemoryContentStore'''
text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit(f"adapter provider block count={count}")
text = text.replace(
    'let result = ShellProvider::execute(&adapters, "pwd", Some("/tmp"))\n            .await\n            .unwrap();',
    '''let result = ShellProvider::run(
            &adapters,
            ShellRequest {
                command: "pwd".into(),
                cwd: Some("/tmp".into()),
                env: BTreeMap::new(),
            },
        )
        .await
        .unwrap();''',
)
path.write_text(text)

path = root / "mahayana-harness-adapters/src/extended.rs"
text = path.read_text()
text = text.replace(
    '''use mahayana_harness_services::{
    AcpProvider, CompactionProvider, CredentialProvider, CredentialReference, SubagentProvider,
    TerminalProvider, WorkflowExecutor,
};''',
    '''use mahayana_harness_services::{
    AcpProvider, AcpRequest, CompactionProvider, CompactionRequest, CredentialProvider,
    CredentialReference, SubagentProvider, SubagentRequest, TerminalProvider, TerminalRequest,
    WorkflowExecutor, WorkflowRequest,
};''',
)
text = text.replace('use crate::{ToolHostAdapters, value_to_bytes};', 'use crate::ToolHostAdapters;')
text = text.replace('const SUBAGENT_RESUME: &str = "subagent.resume";\n', '')
text = text.replace('const SUBAGENT_STOP: &str = "subagent.stop";\n', '')
pattern = re.compile(r"#\[async_trait\]\nimpl TerminalProvider for ToolHostAdapters \{.*?\n\}\n\n#\[derive\(Default\)\]\npub struct MemoryStorageProvider", re.S)
replacement = r'''#[async_trait]
impl TerminalProvider for ToolHostAdapters {
    async fn perform(&self, request: TerminalRequest) -> HarnessResult<Value> {
        let route = match request.operation.as_str() {
            "open" => TERMINAL_OPEN,
            "write" => TERMINAL_WRITE,
            "read" => TERMINAL_READ,
            "close" => TERMINAL_CLOSE,
            operation => {
                return Err(HarnessError::InvalidConfig(format!(
                    "unsupported terminal operation: {operation}"
                )))
            }
        };
        self.invoke_value(
            route,
            json!({
                "operation": request.operation,
                "terminalId": request.terminal_id,
                "data": request.data,
                "cwd": request.cwd,
            }),
        )
        .await
    }
}

#[async_trait]
impl CredentialProvider for ToolHostAdapters {
    async fn store(&self, reference: &CredentialReference, secret: &str) -> HarnessResult<()> {
        self.invoke_value(
            CREDENTIAL_STORE,
            json!({
                "id": reference.id,
                "service": reference.service,
                "account": reference.account,
                "secret": secret,
            }),
        )
        .await?;
        Ok(())
    }

    async fn resolve(&self, reference: &CredentialReference) -> HarnessResult<Option<String>> {
        let value = self
            .invoke_value(
                CREDENTIAL_RESOLVE,
                json!({"id": reference.id, "service": reference.service, "account": reference.account}),
            )
            .await?;
        if value.is_null() {
            return Ok(None);
        }
        if let Some(secret) = value.get("secret").and_then(Value::as_str) {
            return Ok(Some(secret.to_string()));
        }
        Ok(value.as_str().map(str::to_string))
    }

    async fn remove(&self, reference: &CredentialReference) -> HarnessResult<()> {
        self.invoke_value(
            CREDENTIAL_REMOVE,
            json!({"id": reference.id, "service": reference.service, "account": reference.account}),
        )
        .await?;
        Ok(())
    }
}

#[async_trait]
impl CompactionProvider for ToolHostAdapters {
    async fn compact(&self, request: CompactionRequest) -> HarnessResult<Value> {
        self.invoke_value(
            COMPACTION_RUN,
            json!({
                "sessionId": request.session_id,
                "events": request.events,
                "targetTokens": request.target_tokens,
            }),
        )
        .await
    }
}

#[async_trait]
impl SubagentProvider for ToolHostAdapters {
    async fn spawn(&self, request: SubagentRequest) -> HarnessResult<Value> {
        self.invoke_value(
            SUBAGENT_SPAWN,
            json!({
                "parentSessionId": request.parent_session_id,
                "role": request.role,
                "instruction": request.instruction,
                "context": request.context,
            }),
        )
        .await
    }
}

#[async_trait]
impl WorkflowExecutor for ToolHostAdapters {
    async fn execute(&self, request: WorkflowRequest) -> HarnessResult<Value> {
        self.invoke_value(
            WORKFLOW_RUN,
            json!({
                "workflowId": request.workflow_id,
                "sessionId": request.session_id,
                "input": request.input,
            }),
        )
        .await
    }
}

#[async_trait]
impl AcpProvider for ToolHostAdapters {
    async fn call(&self, request: AcpRequest) -> HarnessResult<Value> {
        self.invoke_value(
            ACP_HANDLE,
            json!({"operation": request.operation, "payload": request.payload}),
        )
        .await
    }
}

#[derive(Default)]
pub struct MemoryStorageProvider'''
text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit(f"extended adapter provider block count={count}")
path.write_text(text)

print("Mahayana Harness protocol and adapter reconciliation tail applied")
