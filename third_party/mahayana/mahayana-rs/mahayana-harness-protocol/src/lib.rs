//! Stable, presentation-neutral JSON protocol for Mahayana Harness.
//!
//! Electron, native mobile, CLI and headless hosts can all submit the same
//! request envelope. The protocol intentionally exposes product concepts and
//! opaque JSON payloads rather than Rust implementation details.

use mahayana_core::BuildProfile;
use mahayana_harness::{HarnessError, HarnessResult, MahayanaHarness, PluginManifest};
use mahayana_harness_services::{
    CommandRecord, ContextFragment, HarnessServices, PromptSection, SkillRecord, TeamMember,
    WorkspaceRecord,
};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

pub const HARNESS_PROTOCOL_VERSION: &str = "1";

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HarnessRequest {
    pub request_id: String,
    pub operation: String,
    #[serde(default)]
    pub payload: Value,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HarnessResponse {
    pub request_id: String,
    pub ok: bool,
    #[serde(default)]
    pub result: Value,
    #[serde(default)]
    pub error: Option<HarnessProtocolError>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HarnessProtocolError {
    pub code: String,
    pub message: String,
}

#[derive(Clone)]
pub struct HarnessApi {
    harness: MahayanaHarness,
    services: HarnessServices,
}

impl HarnessApi {
    pub fn new(build_profile: BuildProfile) -> Self {
        let harness = MahayanaHarness::new(build_profile);
        Self {
            services: HarnessServices::new(harness.clone()),
            harness,
        }
    }

    pub fn from_parts(harness: MahayanaHarness, services: HarnessServices) -> HarnessResult<Self> {
        Ok(Self { harness, services })
    }

    pub fn harness(&self) -> &MahayanaHarness {
        &self.harness
    }

    pub fn services(&self) -> &HarnessServices {
        &self.services
    }

    pub fn execute_json(&self, input: &str) -> String {
        let request = match serde_json::from_str::<HarnessRequest>(input) {
            Ok(request) => request,
            Err(error) => {
                return serde_json::to_string(&HarnessResponse {
                    request_id: String::new(),
                    ok: false,
                    result: Value::Null,
                    error: Some(HarnessProtocolError {
                        code: "invalid_request".into(),
                        message: error.to_string(),
                    }),
                })
                .unwrap_or_else(|_| "{\"ok\":false}".into());
            }
        };
        let response = match self.execute(&request.operation, request.payload.clone()) {
            Ok(result) => HarnessResponse {
                request_id: request.request_id,
                ok: true,
                result,
                error: None,
            },
            Err(error) => HarnessResponse {
                request_id: request.request_id,
                ok: false,
                result: Value::Null,
                error: Some(error_to_protocol(error)),
            },
        };
        serde_json::to_string(&response).unwrap_or_else(|_| "{\"ok\":false}".into())
    }

    pub fn execute(&self, operation: &str, payload: Value) -> HarnessResult<Value> {
        match operation {
            "protocol.version" => Ok(json!({"version": HARNESS_PROTOCOL_VERSION})),
            "runtime.snapshot" => to_value(self.harness.snapshot()?),
            "runtime.config" => self.harness.dump_config(),
            "runtime.pollEvent" => to_value(self.harness.poll_event()?),
            "services.snapshot" => self.services.snapshot(),

            "service.register" => {
                self.harness
                    .register_service(required_string(&payload, "name")?)?;
                Ok(Value::Null)
            }
            "service.unregister" => {
                self.harness
                    .unregister_service(required_str(&payload, "name")?)?;
                Ok(Value::Null)
            }
            "profile.register" => {
                self.harness.register_profile(from_payload(payload)?)?;
                Ok(Value::Null)
            }
            "profile.activate" => {
                self.harness
                    .activate_profile(required_str(&payload, "profileId")?)?;
                Ok(Value::Null)
            }
            "plugin.mount" => {
                self.harness
                    .mount_plugin(from_payload::<PluginManifest>(payload)?)?;
                Ok(Value::Null)
            }
            "plugin.unmount" => {
                self.harness
                    .unmount_plugin(required_str(&payload, "pluginId")?)?;
                Ok(Value::Null)
            }

            "session.create" => to_value(
                self.harness
                    .create_session(required_string(&payload, "title")?)?,
            ),
            "session.fork" => to_value(
                self.harness
                    .fork_session(required_str(&payload, "sessionId")?)?,
            ),
            "session.appendEvent" => to_value(self.harness.append_session_event(
                required_str(&payload, "sessionId")?,
                required_string(&payload, "kind")?,
                payload.get("eventPayload").cloned().unwrap_or(Value::Null),
            )?),
            "session.transcript" => Ok(json!({
                "transcript": self
                    .harness
                    .transcript(required_str(&payload, "sessionId")?)?
            })),
            "session.search" => to_value(self.services.search_sessions(
                required_str(&payload, "query")?,
                optional_usize(&payload, "limit").unwrap_or(20),
            )?),

            "agent.spawn" => to_value(self.harness.spawn_agent(
                required_string(&payload, "name")?,
                required_string(&payload, "preset")?,
                required_string(&payload, "sessionId")?,
            )?),
            "goal.create" => to_value(self.harness.set_goal(
                required_str(&payload, "sessionId")?,
                required_string(&payload, "text")?,
            )?),
            "goal.update" => to_value(self.harness.update_goal_status(
                required_str(&payload, "goalId")?,
                required_string(&payload, "status")?,
            )?),
            "job.create" => to_value(
                self.harness
                    .create_job(required_string(&payload, "kind")?)?,
            ),
            "job.update" => to_value(self.harness.update_job(
                required_str(&payload, "jobId")?,
                required_string(&payload, "status")?,
                optional_string(&payload, "resultRef"),
            )?),

            "prompt.register" => {
                self.services
                    .add_prompt_section(from_payload::<PromptSection>(payload)?)?;
                Ok(Value::Null)
            }
            "prompt.assemble" => Ok(json!({"prompt": self.services.assembled_prompt()?})),
            "context.inject" => {
                self.services
                    .inject_context(from_payload::<ContextFragment>(payload)?)?;
                Ok(Value::Null)
            }
            "context.list" => to_value(self.services.assembled_context()?),

            "workspace.register" => {
                self.services
                    .register_workspace(from_payload::<WorkspaceRecord>(payload)?)?;
                Ok(Value::Null)
            }
            "workspace.list" => to_value(self.services.list_workspaces()?),
            "settings.set" => to_value(self.services.set_setting(
                required_string(&payload, "key")?,
                payload.get("value").cloned().unwrap_or(Value::Null),
            )?),
            "settings.get" => to_value(self.services.get_setting(required_str(&payload, "key")?)?),

            "todo.add" => to_value(self.services.add_todo(required_string(&payload, "text")?)?),
            "todo.update" => to_value(self.services.update_todo(
                required_str(&payload, "todoId")?,
                required_string(&payload, "status")?,
            )?),
            "plan.set" => to_value(
                self.services.set_plan(
                    required_string(&payload, "sessionId")?,
                    string_array(&payload, "steps")?,
                    payload
                        .get("reviewRequired")
                        .and_then(Value::as_bool)
                        .unwrap_or(false),
                )?,
            ),
            "plan.exit" => to_value(
                self.services.exit_plan(
                    required_str(&payload, "sessionId")?,
                    payload
                        .get("approved")
                        .and_then(Value::as_bool)
                        .unwrap_or(false),
                )?,
            ),

            "schedule.create" => to_value(self.services.schedule(
                required_string(&payload, "sessionId")?,
                required_string(&payload, "instruction")?,
                required_string(&payload, "schedule")?,
            )?),
            "schedule.setEnabled" => to_value(self.services.set_schedule_enabled(
                required_str(&payload, "scheduleId")?,
                required_bool(&payload, "enabled")?,
            )?),
            "feedback.record" => to_value(self.services.record_feedback(
                required_string(&payload, "sessionId")?,
                required_string(&payload, "kind")?,
                required_string(&payload, "text")?,
            )?),
            "identity.get" => to_value(self.services.identity()?),
            "identity.bindAccount" => to_value(
                self.services
                    .bind_account(required_string(&payload, "accountId")?)?,
            ),

            "team.create" => to_value(
                self.services.create_team(
                    required_string(&payload, "name")?,
                    payload
                        .get("members")
                        .cloned()
                        .map(from_payload::<Vec<TeamMember>>)
                        .transpose()?
                        .unwrap_or_default(),
                )?,
            ),
            "team.addTask" => to_value(self.services.add_team_task(
                required_str(&payload, "teamId")?,
                required_string(&payload, "text")?,
                optional_string(&payload, "assigneeAgentId"),
            )?),
            "team.sendMessage" => to_value(self.services.send_team_message(
                required_str(&payload, "teamId")?,
                required_string(&payload, "fromAgentId")?,
                optional_string(&payload, "toAgentId"),
                required_string(&payload, "text")?,
            )?),

            "skill.register" => {
                self.services
                    .register_skill(from_payload::<SkillRecord>(payload)?)?;
                Ok(Value::Null)
            }
            "command.register" => {
                self.services
                    .register_command(from_payload::<CommandRecord>(payload)?)?;
                Ok(Value::Null)
            }
            _ => Err(HarnessError::ServiceNotFound(format!(
                "protocol operation {operation}"
            ))),
        }
    }
}

fn error_to_protocol(error: HarnessError) -> HarnessProtocolError {
    let code = match error {
        HarnessError::ApprovalRequired(_) => "approval_required",
        HarnessError::ApprovalNotFound(_) => "approval_not_found",
        HarnessError::SessionNotFound(_) => "session_not_found",
        HarnessError::AgentNotFound(_) => "agent_not_found",
        HarnessError::ToolNotFound(_) => "tool_not_found",
        HarnessError::ServiceNotFound(_) => "not_found",
        HarnessError::InvalidConfig(_) => "invalid_config",
        _ => "harness_error",
    };
    HarnessProtocolError {
        code: code.into(),
        message: error.to_string(),
    }
}

fn from_payload<T>(payload: Value) -> HarnessResult<T>
where
    T: for<'de> Deserialize<'de>,
{
    serde_json::from_value(payload).map_err(|error| HarnessError::InvalidConfig(error.to_string()))
}

fn to_value<T: Serialize>(value: T) -> HarnessResult<Value> {
    serde_json::to_value(value).map_err(|error| HarnessError::InvalidConfig(error.to_string()))
}

fn required_str<'a>(payload: &'a Value, key: &str) -> HarnessResult<&'a str> {
    payload
        .get(key)
        .and_then(Value::as_str)
        .filter(|value| !value.trim().is_empty())
        .ok_or_else(|| HarnessError::InvalidConfig(format!("{key} is required")))
}

fn required_string(payload: &Value, key: &str) -> HarnessResult<String> {
    required_str(payload, key).map(str::to_string)
}

fn optional_string(payload: &Value, key: &str) -> Option<String> {
    payload
        .get(key)
        .and_then(Value::as_str)
        .filter(|value| !value.trim().is_empty())
        .map(str::to_string)
}

fn required_bool(payload: &Value, key: &str) -> HarnessResult<bool> {
    payload
        .get(key)
        .and_then(Value::as_bool)
        .ok_or_else(|| HarnessError::InvalidConfig(format!("{key} is required")))
}

fn optional_usize(payload: &Value, key: &str) -> Option<usize> {
    payload
        .get(key)
        .and_then(Value::as_u64)
        .and_then(|value| usize::try_from(value).ok())
}

fn string_array(payload: &Value, key: &str) -> HarnessResult<Vec<String>> {
    let array = payload
        .get(key)
        .and_then(Value::as_array)
        .ok_or_else(|| HarnessError::InvalidConfig(format!("{key} must be an array")))?;
    array
        .iter()
        .map(|value| {
            value
                .as_str()
                .map(str::to_string)
                .ok_or_else(|| HarnessError::InvalidConfig(format!("{key} must contain strings")))
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn json_protocol_round_trips_session_and_search() {
        let api = HarnessApi::new(BuildProfile::DesktopFull);
        let created: HarnessResponse = serde_json::from_str(&api.execute_json(
            r#"{"requestId":"1","operation":"session.create","payload":{"title":"protocol"}}"#,
        ))
        .unwrap();
        assert!(created.ok);
        let session_id = created.result["id"].as_str().unwrap().to_string();

        let append = HarnessRequest {
            request_id: "2".into(),
            operation: "session.appendEvent".into(),
            payload: json!({
                "sessionId": session_id,
                "kind": "user/message",
                "eventPayload": {"text": "needle protocol"}
            }),
        };
        let append: HarnessResponse =
            serde_json::from_str(&api.execute_json(&serde_json::to_string(&append).unwrap()))
                .unwrap();
        assert!(append.ok);

        let search = api
            .execute("session.search", json!({"query": "needle", "limit": 10}))
            .unwrap();
        assert_eq!(search.as_array().unwrap().len(), 1);
    }

    #[test]
    fn unknown_operation_returns_stable_error() {
        let api = HarnessApi::new(BuildProfile::DesktopFull);
        let response: HarnessResponse = serde_json::from_str(
            &api.execute_json(r#"{"requestId":"x","operation":"missing.operation"}"#),
        )
        .unwrap();
        assert!(!response.ok);
        assert_eq!(response.error.unwrap().code, "not_found");
    }
}
