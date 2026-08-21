from pathlib import Path

root = Path("third_party/mahayana/mahayana-rs")
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

old = '''            "workspace.register" => {
                self.services
                    .register_workspace(from_payload::<WorkspaceRecord>(payload)?)?;
                Ok(Value::Null)
            }
            "workspace.list" => to_value(self.services.list_workspaces()?),
'''
new = '''            "workspace.register" => to_value(self.services.register_workspace(
                required_string(&payload, "root")?,
                required_string(&payload, "label")?,
            )?),
            "workspace.list" => to_value(self.services.workspaces()?),
'''
if old in text:
    text = text.replace(old, new, 1)

old = '''            "todo.update" => to_value(self.services.update_todo(
                required_str(&payload, "todoId")?,
                required_string(&payload, "status")?,
            )?),
'''
new = '''            "todo.update" => to_value(self.services.update_todo(
                required_str(&payload, "todoId")?,
                todo_done(&payload)?,
            )?),
'''
if old in text:
    text = text.replace(old, new, 1)

old = '''            "feedback.record" => to_value(self.services.record_feedback(
                required_string(&payload, "sessionId")?,
                required_string(&payload, "kind")?,
                required_string(&payload, "text")?,
            )?),
'''
new = '''            "feedback.record" => to_value(self.services.record_feedback(
                optional_string(&payload, "sessionId"),
                optional_i32(&payload, "rating"),
                optional_string(&payload, "note").or_else(|| optional_string(&payload, "text")),
            )?),
'''
if old in text:
    text = text.replace(old, new, 1)

old = '''            "identity.bindAccount" => to_value(
                self.services
                    .bind_account(required_string(&payload, "accountId")?)?,
            ),
'''
new = '''            "identity.bindAccount" => to_value(self.services.bind_identity_account(
                Some(required_string(&payload, "accountId")?),
                optional_string(&payload, "displayName"),
            )?),
'''
if old in text:
    text = text.replace(old, new, 1)

old = '''            "team.addTask" => to_value(self.services.add_team_task(
                required_str(&payload, "teamId")?,
                required_string(&payload, "text")?,
                optional_string(&payload, "assigneeAgentId"),
            )?),
'''
new = '''            "team.addTask" => to_value(self.services.add_team_task(
                required_str(&payload, "teamId")?,
                optional_string(&payload, "assigneeAgentId").unwrap_or_else(|| "unassigned".into()),
                required_string(&payload, "text")?,
            )?),
'''
if old in text:
    text = text.replace(old, new, 1)

old = '''            "team.sendMessage" => to_value(self.services.send_team_message(
                required_str(&payload, "teamId")?,
                required_string(&payload, "fromAgentId")?,
                optional_string(&payload, "toAgentId"),
                required_string(&payload, "text")?,
            )?),
'''
new = '''            "team.sendMessage" => to_value(self.services.send_team_message(
                required_str(&payload, "teamId")?,
                required_string(&payload, "fromAgentId")?,
                optional_string(&payload, "toAgentId"),
                payload.get("message").cloned().unwrap_or(Value::String(required_string(&payload, "text")?)),
            )?),
'''
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
print("Mahayana Harness protocol compatibility tail applied")
