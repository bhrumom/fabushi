use crate::actor::ActorId;
use crate::conversation::ConversationId;
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct MiniAppServiceCallId(pub String);

impl MiniAppServiceCallId {
    pub fn new(value: impl Into<String>) -> Self {
        Self(value.into())
    }

    pub fn is_valid(&self) -> bool {
        let value = self.0.trim();
        !value.is_empty() && value.len() <= 200
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum MiniAppServiceCallMode {
    Voice,
    Text,
    Hybrid,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum MiniAppServiceCallState {
    Connecting,
    Active,
    Held,
    Ended,
    Failed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum MiniAppServiceCallInputSource {
    Dtmf,
    Speech,
    Chat,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    rename_all = "camelCase",
    rename_all_fields = "camelCase",
    tag = "type"
)]
pub enum MiniAppServiceCallInput {
    Dtmf {
        digits: String,
    },
    SpeechTranscript {
        text: String,
        is_final: bool,
        confidence_bps: Option<u16>,
    },
    ChatText {
        text: String,
    },
}

impl MiniAppServiceCallInput {
    pub fn source(&self) -> MiniAppServiceCallInputSource {
        match self {
            Self::Dtmf { .. } => MiniAppServiceCallInputSource::Dtmf,
            Self::SpeechTranscript { .. } => MiniAppServiceCallInputSource::Speech,
            Self::ChatText { .. } => MiniAppServiceCallInputSource::Chat,
        }
    }

    pub fn transcript_text(&self) -> Option<&str> {
        match self {
            Self::Dtmf { .. } => None,
            Self::SpeechTranscript { text, .. } | Self::ChatText { text } => Some(text),
        }
    }

    pub fn requires_intent_resolution(&self) -> bool {
        match self {
            Self::Dtmf { .. } => false,
            Self::SpeechTranscript { is_final, .. } => *is_final,
            Self::ChatText { .. } => true,
        }
    }

    fn validate(&self) -> Result<(), MiniAppServiceCallError> {
        match self {
            Self::Dtmf { digits } => {
                if digits.is_empty()
                    || digits.len() > 32
                    || !digits
                        .chars()
                        .all(|ch| ch.is_ascii_digit() || matches!(ch, '*' | '#'))
                {
                    return Err(MiniAppServiceCallError::InvalidDtmf);
                }
            }
            Self::SpeechTranscript {
                text,
                confidence_bps,
                ..
            } => {
                if text.trim().is_empty() || text.len() > 16_000 {
                    return Err(MiniAppServiceCallError::InvalidTranscript);
                }
                if confidence_bps.is_some_and(|value| value > 10_000) {
                    return Err(MiniAppServiceCallError::InvalidConfidence);
                }
            }
            Self::ChatText { text } => {
                if text.trim().is_empty() || text.len() > 16_000 {
                    return Err(MiniAppServiceCallError::InvalidTranscript);
                }
            }
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MiniAppServiceCallTurn {
    pub sequence: u64,
    pub actor_id: ActorId,
    pub input: MiniAppServiceCallInput,
    pub created_at_ms: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MiniAppServiceActionRequest {
    pub call_id: MiniAppServiceCallId,
    pub mini_app_id: String,
    pub conversation_id: ConversationId,
    pub turn_sequence: u64,
    pub input: MiniAppServiceCallInput,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MiniAppServiceActionResult {
    pub action_id: String,
    pub intent: String,
    pub success: bool,
    pub spoken_response: Option<String>,
    pub display_response: Option<String>,
    pub completed_at_ms: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    rename_all = "camelCase",
    rename_all_fields = "camelCase",
    tag = "type"
)]
pub enum MiniAppServiceCallEffect {
    RouteDtmf {
        call_id: MiniAppServiceCallId,
        digits: String,
        turn_sequence: u64,
    },
    ResolveIntent {
        request: MiniAppServiceActionRequest,
    },
    AppendConversationTranscript {
        conversation_id: ConversationId,
        actor_id: ActorId,
        source: MiniAppServiceCallInputSource,
        text: String,
        final_segment: bool,
        turn_sequence: u64,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MiniAppServiceCallSession {
    pub id: MiniAppServiceCallId,
    pub mini_app_id: String,
    pub mini_app_session_id: Option<String>,
    pub conversation_id: ConversationId,
    pub caller_actor_id: ActorId,
    pub service_actor_id: Option<ActorId>,
    pub mode: MiniAppServiceCallMode,
    pub state: MiniAppServiceCallState,
    pub turns: Vec<MiniAppServiceCallTurn>,
    pub action_results: Vec<MiniAppServiceActionResult>,
    pub started_at_ms: i64,
    pub updated_at_ms: i64,
    pub ended_at_ms: Option<i64>,
}

impl MiniAppServiceCallSession {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        id: MiniAppServiceCallId,
        mini_app_id: impl Into<String>,
        mini_app_session_id: Option<String>,
        conversation_id: ConversationId,
        caller_actor_id: ActorId,
        service_actor_id: Option<ActorId>,
        mode: MiniAppServiceCallMode,
        started_at_ms: i64,
    ) -> Result<Self, MiniAppServiceCallError> {
        let mini_app_id = mini_app_id.into();
        if !id.is_valid() || mini_app_id.trim().is_empty() || mini_app_id.len() > 200 {
            return Err(MiniAppServiceCallError::InvalidSession);
        }
        Ok(Self {
            id,
            mini_app_id,
            mini_app_session_id,
            conversation_id,
            caller_actor_id,
            service_actor_id,
            mode,
            state: MiniAppServiceCallState::Connecting,
            turns: Vec::new(),
            action_results: Vec::new(),
            started_at_ms,
            updated_at_ms: started_at_ms,
            ended_at_ms: None,
        })
    }

    pub fn activate(&mut self, now_ms: i64) -> Result<(), MiniAppServiceCallError> {
        if !matches!(
            self.state,
            MiniAppServiceCallState::Connecting | MiniAppServiceCallState::Held
        ) {
            return Err(MiniAppServiceCallError::InvalidState(self.state));
        }
        self.state = MiniAppServiceCallState::Active;
        self.updated_at_ms = now_ms;
        Ok(())
    }

    pub fn submit_input(
        &mut self,
        actor_id: ActorId,
        input: MiniAppServiceCallInput,
        now_ms: i64,
    ) -> Result<Vec<MiniAppServiceCallEffect>, MiniAppServiceCallError> {
        if self.state != MiniAppServiceCallState::Active {
            return Err(MiniAppServiceCallError::InvalidState(self.state));
        }
        if actor_id != self.caller_actor_id {
            return Err(MiniAppServiceCallError::ActorNotAllowed);
        }
        input.validate()?;

        let sequence = u64::try_from(self.turns.len())
            .unwrap_or(u64::MAX)
            .saturating_add(1);
        self.turns.push(MiniAppServiceCallTurn {
            sequence,
            actor_id: actor_id.clone(),
            input: input.clone(),
            created_at_ms: now_ms,
        });
        self.updated_at_ms = now_ms;

        let mut effects = Vec::new();
        match &input {
            MiniAppServiceCallInput::Dtmf { digits } => {
                effects.push(MiniAppServiceCallEffect::RouteDtmf {
                    call_id: self.id.clone(),
                    digits: digits.clone(),
                    turn_sequence: sequence,
                });
            }
            MiniAppServiceCallInput::SpeechTranscript { text, is_final, .. } => {
                effects.push(MiniAppServiceCallEffect::AppendConversationTranscript {
                    conversation_id: self.conversation_id.clone(),
                    actor_id: actor_id.clone(),
                    source: MiniAppServiceCallInputSource::Speech,
                    text: text.clone(),
                    final_segment: *is_final,
                    turn_sequence: sequence,
                });
            }
            MiniAppServiceCallInput::ChatText { text } => {
                effects.push(MiniAppServiceCallEffect::AppendConversationTranscript {
                    conversation_id: self.conversation_id.clone(),
                    actor_id: actor_id.clone(),
                    source: MiniAppServiceCallInputSource::Chat,
                    text: text.clone(),
                    final_segment: true,
                    turn_sequence: sequence,
                });
            }
        }

        if input.requires_intent_resolution() {
            effects.push(MiniAppServiceCallEffect::ResolveIntent {
                request: MiniAppServiceActionRequest {
                    call_id: self.id.clone(),
                    mini_app_id: self.mini_app_id.clone(),
                    conversation_id: self.conversation_id.clone(),
                    turn_sequence: sequence,
                    input,
                },
            });
        }
        Ok(effects)
    }

    pub fn record_action_result(
        &mut self,
        result: MiniAppServiceActionResult,
    ) -> Result<(), MiniAppServiceCallError> {
        if matches!(
            self.state,
            MiniAppServiceCallState::Ended | MiniAppServiceCallState::Failed
        ) {
            return Err(MiniAppServiceCallError::InvalidState(self.state));
        }
        if result.action_id.trim().is_empty() || result.intent.trim().is_empty() {
            return Err(MiniAppServiceCallError::InvalidActionResult);
        }
        self.updated_at_ms = result.completed_at_ms;
        self.action_results.push(result);
        Ok(())
    }

    pub fn end(&mut self, now_ms: i64) -> Result<(), MiniAppServiceCallError> {
        if matches!(
            self.state,
            MiniAppServiceCallState::Ended | MiniAppServiceCallState::Failed
        ) {
            return Err(MiniAppServiceCallError::InvalidState(self.state));
        }
        self.state = MiniAppServiceCallState::Ended;
        self.updated_at_ms = now_ms;
        self.ended_at_ms = Some(now_ms);
        Ok(())
    }
}

#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum MiniAppServiceCallError {
    #[error("MiniApp service call session is invalid")]
    InvalidSession,
    #[error("MiniApp service call is not writable in state {0:?}")]
    InvalidState(MiniAppServiceCallState),
    #[error("actor is not allowed to submit input to this MiniApp service call")]
    ActorNotAllowed,
    #[error("DTMF input is invalid")]
    InvalidDtmf,
    #[error("transcript input is invalid")]
    InvalidTranscript,
    #[error("speech confidence must be between 0 and 10000 basis points")]
    InvalidConfidence,
    #[error("MiniApp action result is invalid")]
    InvalidActionResult,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn session() -> MiniAppServiceCallSession {
        MiniAppServiceCallSession::new(
            MiniAppServiceCallId::new("svc-call:1"),
            "miniapp:carrier",
            Some("miniapp-session:1".into()),
            ConversationId("conversation:carrier".into()),
            ActorId("actor:user".into()),
            Some(ActorId("actor:carrier-service".into())),
            MiniAppServiceCallMode::Hybrid,
            100,
        )
        .expect("valid session")
    }

    #[test]
    fn dtmf_routes_without_ai_intent_resolution() {
        let mut call = session();
        call.activate(110).expect("activate");
        let effects = call
            .submit_input(
                ActorId("actor:user".into()),
                MiniAppServiceCallInput::Dtmf {
                    digits: "12#".into(),
                },
                120,
            )
            .expect("submit dtmf");
        assert_eq!(effects.len(), 1);
        assert!(matches!(
            &effects[0],
            MiniAppServiceCallEffect::RouteDtmf { digits, .. } if digits == "12#"
        ));
    }

    #[test]
    fn final_speech_is_transcribed_and_sent_to_ai_intent_resolution() {
        let mut call = session();
        call.activate(110).expect("activate");
        let effects = call
            .submit_input(
                ActorId("actor:user".into()),
                MiniAppServiceCallInput::SpeechTranscript {
                    text: "帮我查一下本月套餐余量".into(),
                    is_final: true,
                    confidence_bps: Some(9_500),
                },
                120,
            )
            .expect("submit speech");
        assert_eq!(effects.len(), 2);
        assert!(effects.iter().any(|effect| matches!(
            effect,
            MiniAppServiceCallEffect::AppendConversationTranscript {
                source: MiniAppServiceCallInputSource::Speech,
                final_segment: true,
                ..
            }
        )));
        assert!(effects.iter().any(|effect| matches!(
            effect,
            MiniAppServiceCallEffect::ResolveIntent { request } if request.mini_app_id == "miniapp:carrier"
        )));
    }

    #[test]
    fn interim_speech_is_visible_but_not_executed() {
        let mut call = session();
        call.activate(110).expect("activate");
        let effects = call
            .submit_input(
                ActorId("actor:user".into()),
                MiniAppServiceCallInput::SpeechTranscript {
                    text: "帮我查一下".into(),
                    is_final: false,
                    confidence_bps: None,
                },
                120,
            )
            .expect("submit speech");
        assert_eq!(effects.len(), 1);
        assert!(matches!(
            &effects[0],
            MiniAppServiceCallEffect::AppendConversationTranscript {
                final_segment: false,
                ..
            }
        ));
    }

    #[test]
    fn chat_text_uses_same_intent_pipeline_as_final_speech() {
        let mut call = session();
        call.activate(110).expect("activate");
        let effects = call
            .submit_input(
                ActorId("actor:user".into()),
                MiniAppServiceCallInput::ChatText {
                    text: "把套餐改成最低月租".into(),
                },
                120,
            )
            .expect("submit chat text");
        assert!(effects
            .iter()
            .any(|effect| matches!(effect, MiniAppServiceCallEffect::ResolveIntent { .. })));
    }

    #[test]
    fn ended_call_rejects_new_input() {
        let mut call = session();
        call.activate(110).expect("activate");
        call.end(120).expect("end");
        let error = call
            .submit_input(
                ActorId("actor:user".into()),
                MiniAppServiceCallInput::ChatText {
                    text: "继续".into(),
                },
                130,
            )
            .expect_err("ended call must reject input");
        assert_eq!(
            error,
            MiniAppServiceCallError::InvalidState(MiniAppServiceCallState::Ended)
        );
    }

    #[test]
    fn action_results_are_auditable_on_the_call_session() {
        let mut call = session();
        call.activate(110).expect("activate");
        call.record_action_result(MiniAppServiceActionResult {
            action_id: "action:1".into(),
            intent: "query_allowance".into(),
            success: true,
            spoken_response: Some("本月还剩 20GB".into()),
            display_response: Some("剩余流量 20GB".into()),
            completed_at_ms: 130,
        })
        .expect("record result");
        assert_eq!(call.action_results.len(), 1);
        assert_eq!(call.action_results[0].intent, "query_allowance");
    }
}
