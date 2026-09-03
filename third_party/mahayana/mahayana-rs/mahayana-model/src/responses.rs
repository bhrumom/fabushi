use crate::{ModelError, ModelEvent, ModelRequest, ModelRuntime, ModelUsage, SharedModelEventSink};
use async_trait::async_trait;
use mahayana_core::ModelProviderMode;
use serde_json::{Map, Value, json};
use std::collections::BTreeMap;
use std::io::{BufRead, BufReader, Read};

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum ResponsesWireApi {
    #[default]
    Responses,
    ChatCompletions,
    AnthropicMessages,
}

#[derive(Debug, Clone)]
pub struct ResponsesModelConfig {
    pub base_url: String,
    pub default_model: String,
    pub bearer_token: Option<String>,
    pub provider_mode: ModelProviderMode,
    pub wire_api: ResponsesWireApi,
}

impl ResponsesModelConfig {
    pub fn validate(&self) -> Result<(), ModelError> {
        if self.default_model.trim().is_empty() {
            return Err(ModelError::InvalidRequest(
                "default model must not be empty".into(),
            ));
        }
        if !self.base_url.starts_with("https://")
            && !matches!(self.provider_mode, ModelProviderMode::LocalLoopback)
        {
            return Err(ModelError::InvalidRequest(
                "remote model endpoints must use HTTPS".into(),
            ));
        }
        if self
            .bearer_token
            .as_deref()
            .is_some_and(|token| token.trim().is_empty() || token.contains(['\r', '\n']))
        {
            return Err(ModelError::InvalidRequest(
                "model credential contains invalid header characters".into(),
            ));
        }
        Ok(())
    }
}

/// Provider-neutral Responses API implementation of Mahayana's model boundary.
///
/// This component performs model inference only. It does not host an Agent,
/// execute tools, own workspace state, or make policy decisions; those belong
/// to `mahayana-native-engine` and the sovereign kernel.
pub struct ResponsesModelRuntime {
    config: ResponsesModelConfig,
}

impl ResponsesModelRuntime {
    pub fn new(config: ResponsesModelConfig) -> Result<Self, ModelError> {
        config.validate()?;
        Ok(Self { config })
    }
}

#[async_trait]
impl ModelRuntime for ResponsesModelRuntime {
    async fn infer(
        &self,
        mut request: ModelRequest,
        events: SharedModelEventSink,
    ) -> Result<(), ModelError> {
        if request.model.trim().is_empty() {
            request.model = self.config.default_model.clone();
        }
        if request.model.trim().is_empty() {
            return Err(ModelError::InvalidRequest("model must not be empty".into()));
        }

        let config = self.config.clone();
        let stream_events = events.clone();
        let payload = tokio::task::spawn_blocking(move || {
            request_response(&config, request, &stream_events)
        })
        .await
        .map_err(|error| ModelError::Inference(format!("model task failed: {error}")))??;

        if let Some(usage) = extract_usage(&payload) {
            events.emit(ModelEvent::Usage(usage))?;
        }
        events.emit(ModelEvent::Completed { output: payload })
    }

    fn provider_mode(&self) -> ModelProviderMode {
        self.config.provider_mode
    }
}

fn request_response(
    config: &ResponsesModelConfig,
    request: ModelRequest,
    events: &SharedModelEventSink,
) -> Result<Value, ModelError> {
    if matches!(
        config.provider_mode,
        ModelProviderMode::UserConfiguredRemote
    ) && config.bearer_token.is_none()
    {
        return Err(ModelError::InvalidRequest(
            "selected model provider credential is not configured".into(),
        ));
    }
    let (endpoint, body) = match config.wire_api {
        ResponsesWireApi::Responses => {
            let endpoint = if config.base_url.ends_with("/responses") {
                config.base_url.clone()
            } else {
                format!("{}/responses", config.base_url.trim_end_matches('/'))
            };
            let mut body =
                json!({ "model": request.model, "input": request.input, "stream": true });
            for key in [
                "tools",
                "tool_choice",
                "parallel_tool_calls",
                "instructions",
                "reasoning",
                "text",
                "temperature",
                "max_output_tokens",
            ] {
                if let Some(value) = request.metadata.get(key) {
                    body[key] = value.clone();
                }
            }
            (endpoint, body)
        }
        ResponsesWireApi::ChatCompletions => {
            let endpoint = if config.base_url.ends_with("/chat/completions") {
                config.base_url.clone()
            } else {
                format!("{}/chat/completions", config.base_url.trim_end_matches('/'))
            };
            let mut messages = chat_messages(&request.input);
            if let Some(instructions) = request.metadata.get("instructions").and_then(Value::as_str)
                && !instructions.trim().is_empty()
            {
                messages.insert(0, json!({"role":"system", "content": instructions}));
            }
            let mut body = json!({ "model": request.model, "messages": messages, "stream": true, "stream_options": {"include_usage": true} });
            if let Some(tools) = request.metadata.get("tools").and_then(Value::as_array) {
                body["tools"] = Value::Array(tools.iter().filter_map(chat_tool).collect());
            }
            for key in ["tool_choice", "parallel_tool_calls", "temperature"] {
                if let Some(value) = request.metadata.get(key) {
                    body[key] = value.clone();
                }
            }
            if let Some(value) = request.metadata.get("max_output_tokens") {
                body["max_tokens"] = value.clone();
            }
            (endpoint, body)
        }
        ResponsesWireApi::AnthropicMessages => {
            let endpoint = if config.base_url.ends_with("/messages") {
                config.base_url.clone()
            } else {
                format!("{}/messages", config.base_url.trim_end_matches('/'))
            };
            let mut body = json!({
                "model": request.model,
                "messages": anthropic_messages(&request.input),
                "max_tokens": request.metadata.get("max_output_tokens").cloned().unwrap_or_else(|| json!(4096)),
                "stream": true,
            });
            let system = anthropic_system(&request.input, request.metadata.get("instructions"));
            if !system.is_empty() {
                body["system"] = json!(system);
            }
            if let Some(tools) = request.metadata.get("tools").and_then(Value::as_array) {
                body["tools"] = Value::Array(tools.iter().filter_map(anthropic_tool).collect());
            }
            if let Some(value) = request.metadata.get("temperature") {
                body["temperature"] = value.clone();
            }
            (endpoint, body)
        }
    };

    let mut http = ureq::post(&endpoint).set("Accept", "text/event-stream, application/json");
    if let Some(token) = config.bearer_token.as_deref() {
        http = match config.wire_api {
            ResponsesWireApi::AnthropicMessages => http
                .set("x-api-key", token)
                .set("anthropic-version", "2023-06-01"),
            ResponsesWireApi::Responses | ResponsesWireApi::ChatCompletions => {
                http.set("Authorization", &format!("Bearer {token}"))
            }
        };
    }
    let response = http.send_json(body).map_err(redacted_http_error)?;
    let content_type = response
        .header("content-type")
        .unwrap_or_default()
        .to_ascii_lowercase();
    if content_type.contains("text/event-stream") {
        return parse_sse_response(config.wire_api, response.into_reader(), events);
    }

    // Compatibility fallback for gateways which ignore `stream: true`. The
    // presentation still receives one delta, but only after the non-streaming
    // response completes; first-party and supported provider routes use SSE.
    let payload: Value = response
        .into_json()
        .map_err(|_| ModelError::Inference("model endpoint returned invalid JSON".into()))?;
    if let Some(error) = payload.get("error") {
        let message = error
            .get("message")
            .and_then(Value::as_str)
            .unwrap_or("model endpoint returned an error");
        return Err(ModelError::Inference(message.to_string()));
    }
    let payload = match config.wire_api {
        ResponsesWireApi::Responses => payload,
        ResponsesWireApi::ChatCompletions => normalize_chat_payload(payload),
        ResponsesWireApi::AnthropicMessages => normalize_anthropic_payload(payload),
    };
    if let Some(text) = extract_output_text(&payload) {
        events.emit(ModelEvent::OutputTextDelta(text))?;
    }
    Ok(payload)
}

#[derive(Debug, Default)]
struct ChatToolCallStream {
    id: String,
    name: String,
    arguments: String,
}

#[derive(Debug, Default)]
struct ChatStreamState {
    id: Value,
    text: String,
    tool_calls: BTreeMap<usize, ChatToolCallStream>,
    usage: Value,
}

#[derive(Debug)]
enum AnthropicBlockStream {
    Text(String),
    Tool { id: String, name: String, arguments: String },
}

#[derive(Debug, Default)]
struct AnthropicStreamState {
    id: Value,
    blocks: BTreeMap<usize, AnthropicBlockStream>,
    usage: Map<String, Value>,
}

#[derive(Debug, Default)]
struct ResponsesStreamState {
    completed: Option<Value>,
    text: String,
}

fn parse_sse_response(
    wire_api: ResponsesWireApi,
    reader: impl Read,
    events: &SharedModelEventSink,
) -> Result<Value, ModelError> {
    let mut reader = BufReader::new(reader);
    let mut line = String::new();
    let mut event_name = String::new();
    let mut data_lines = Vec::new();
    let mut responses = ResponsesStreamState::default();
    let mut chat = ChatStreamState::default();
    let mut anthropic = AnthropicStreamState::default();

    loop {
        line.clear();
        let read = reader
            .read_line(&mut line)
            .map_err(|error| ModelError::Inference(format!("model stream read failed: {error}")))?;
        if read == 0 {
            if !data_lines.is_empty() {
                process_sse_frame(
                    wire_api,
                    &event_name,
                    &data_lines.join("\n"),
                    events,
                    &mut responses,
                    &mut chat,
                    &mut anthropic,
                )?;
            }
            break;
        }
        let trimmed = line.trim_end_matches(['\r', '\n']);
        if trimmed.is_empty() {
            if !data_lines.is_empty() {
                process_sse_frame(
                    wire_api,
                    &event_name,
                    &data_lines.join("\n"),
                    events,
                    &mut responses,
                    &mut chat,
                    &mut anthropic,
                )?;
            }
            event_name.clear();
            data_lines.clear();
            continue;
        }
        if let Some(value) = trimmed.strip_prefix("event:") {
            event_name = value.trim().to_string();
        } else if let Some(value) = trimmed.strip_prefix("data:") {
            data_lines.push(value.trim_start().to_string());
        }
    }

    match wire_api {
        ResponsesWireApi::Responses => finish_responses_stream(responses),
        ResponsesWireApi::ChatCompletions => Ok(finish_chat_stream(chat)),
        ResponsesWireApi::AnthropicMessages => Ok(finish_anthropic_stream(anthropic)),
    }
}

#[allow(clippy::too_many_arguments)]
fn process_sse_frame(
    wire_api: ResponsesWireApi,
    event_name: &str,
    data: &str,
    events: &SharedModelEventSink,
    responses: &mut ResponsesStreamState,
    chat: &mut ChatStreamState,
    anthropic: &mut AnthropicStreamState,
) -> Result<(), ModelError> {
    if data.trim().is_empty() || data.trim() == "[DONE]" {
        return Ok(());
    }
    let payload: Value = serde_json::from_str(data)
        .map_err(|error| ModelError::Inference(format!("model stream returned invalid JSON: {error}")))?;
    if let Some(error) = payload.get("error") {
        let message = error
            .get("message")
            .and_then(Value::as_str)
            .unwrap_or("model stream returned an error");
        return Err(ModelError::Inference(message.to_string()));
    }

    match wire_api {
        ResponsesWireApi::Responses => process_responses_frame(payload, events, responses),
        ResponsesWireApi::ChatCompletions => process_chat_frame(payload, events, chat),
        ResponsesWireApi::AnthropicMessages => {
            process_anthropic_frame(event_name, payload, events, anthropic)
        }
    }
}

fn process_responses_frame(
    payload: Value,
    events: &SharedModelEventSink,
    state: &mut ResponsesStreamState,
) -> Result<(), ModelError> {
    match payload.get("type").and_then(Value::as_str) {
        Some("response.output_text.delta") => {
            if let Some(delta) = payload.get("delta").and_then(Value::as_str)
                && !delta.is_empty()
            {
                state.text.push_str(delta);
                events.emit(ModelEvent::OutputTextDelta(delta.to_string()))?;
            }
        }
        Some("response.completed") | Some("response.incomplete") => {
            state.completed = payload.get("response").cloned();
        }
        Some("response.failed") => {
            let message = payload
                .pointer("/response/error/message")
                .or_else(|| payload.pointer("/error/message"))
                .and_then(Value::as_str)
                .unwrap_or("model response failed");
            return Err(ModelError::Inference(message.to_string()));
        }
        _ => {}
    }
    Ok(())
}

fn finish_responses_stream(state: ResponsesStreamState) -> Result<Value, ModelError> {
    if let Some(response) = state.completed {
        return Ok(response);
    }
    if state.text.is_empty() {
        return Err(ModelError::Inference(
            "model stream ended without a completed response".into(),
        ));
    }
    Ok(json!({
        "output": [{
            "type": "message",
            "role": "assistant",
            "content": [{"type": "output_text", "text": state.text}],
        }]
    }))
}

fn process_chat_frame(
    payload: Value,
    events: &SharedModelEventSink,
    state: &mut ChatStreamState,
) -> Result<(), ModelError> {
    if payload.get("id").is_some_and(|value| !value.is_null()) {
        state.id = payload.get("id").cloned().unwrap_or(Value::Null);
    }
    if let Some(usage) = payload.get("usage")
        && !usage.is_null()
    {
        state.usage = usage.clone();
    }
    if let Some(delta) = payload.pointer("/choices/0/delta/content").and_then(Value::as_str)
        && !delta.is_empty()
    {
        state.text.push_str(delta);
        events.emit(ModelEvent::OutputTextDelta(delta.to_string()))?;
    }
    for call in payload
        .pointer("/choices/0/delta/tool_calls")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
    {
        let index = call.get("index").and_then(Value::as_u64).unwrap_or(0) as usize;
        let target = state.tool_calls.entry(index).or_default();
        if let Some(id) = call.get("id").and_then(Value::as_str) {
            target.id = id.to_string();
        }
        if let Some(name) = call.pointer("/function/name").and_then(Value::as_str) {
            target.name.push_str(name);
        }
        if let Some(arguments) = call.pointer("/function/arguments").and_then(Value::as_str) {
            target.arguments.push_str(arguments);
        }
    }
    Ok(())
}

fn finish_chat_stream(state: ChatStreamState) -> Value {
    let tool_calls = state
        .tool_calls
        .into_values()
        .map(|call| {
            json!({
                "id": if call.id.is_empty() { "call" } else { call.id.as_str() },
                "type": "function",
                "function": {
                    "name": if call.name.is_empty() { "tool" } else { call.name.as_str() },
                    "arguments": if call.arguments.is_empty() { "{}" } else { call.arguments.as_str() },
                },
            })
        })
        .collect::<Vec<_>>();
    normalize_chat_payload(json!({
        "id": state.id,
        "choices": [{
            "message": {
                "role": "assistant",
                "content": state.text,
                "tool_calls": tool_calls,
            }
        }],
        "usage": state.usage,
    }))
}

fn merge_usage(target: &mut Map<String, Value>, incoming: &Value) {
    let Some(incoming) = incoming.as_object() else { return; };
    for (key, value) in incoming {
        target.insert(key.clone(), value.clone());
    }
}

fn process_anthropic_frame(
    event_name: &str,
    payload: Value,
    events: &SharedModelEventSink,
    state: &mut AnthropicStreamState,
) -> Result<(), ModelError> {
    let kind = payload
        .get("type")
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .unwrap_or(event_name);
    match kind {
        "message_start" => {
            if let Some(message) = payload.get("message") {
                state.id = message.get("id").cloned().unwrap_or(Value::Null);
                if let Some(usage) = message.get("usage") {
                    merge_usage(&mut state.usage, usage);
                }
            }
        }
        "content_block_start" => {
            let index = payload.get("index").and_then(Value::as_u64).unwrap_or(0) as usize;
            let block = payload.get("content_block").unwrap_or(&Value::Null);
            match block.get("type").and_then(Value::as_str) {
                Some("text") => {
                    let text = block.get("text").and_then(Value::as_str).unwrap_or_default();
                    state.blocks.insert(index, AnthropicBlockStream::Text(text.to_string()));
                }
                Some("tool_use") => {
                    let arguments = block
                        .get("input")
                        .filter(|value| !value.is_null())
                        .and_then(|value| serde_json::to_string(value).ok())
                        .filter(|value| value != "{}")
                        .unwrap_or_default();
                    state.blocks.insert(index, AnthropicBlockStream::Tool {
                        id: block.get("id").and_then(Value::as_str).unwrap_or("tool").to_string(),
                        name: block.get("name").and_then(Value::as_str).unwrap_or("tool").to_string(),
                        arguments,
                    });
                }
                _ => {}
            }
        }
        "content_block_delta" => {
            let index = payload.get("index").and_then(Value::as_u64).unwrap_or(0) as usize;
            let delta = payload.get("delta").unwrap_or(&Value::Null);
            match delta.get("type").and_then(Value::as_str) {
                Some("text_delta") => {
                    let text = delta.get("text").and_then(Value::as_str).unwrap_or_default();
                    if !text.is_empty() {
                        match state.blocks.entry(index).or_insert_with(|| AnthropicBlockStream::Text(String::new())) {
                            AnthropicBlockStream::Text(buffer) => buffer.push_str(text),
                            AnthropicBlockStream::Tool { .. } => {}
                        }
                        events.emit(ModelEvent::OutputTextDelta(text.to_string()))?;
                    }
                }
                Some("input_json_delta") => {
                    let partial = delta.get("partial_json").and_then(Value::as_str).unwrap_or_default();
                    if let Some(AnthropicBlockStream::Tool { arguments, .. }) = state.blocks.get_mut(&index) {
                        arguments.push_str(partial);
                    }
                }
                _ => {}
            }
        }
        "message_delta" => {
            if let Some(usage) = payload.get("usage") {
                merge_usage(&mut state.usage, usage);
            }
        }
        "error" => {
            let message = payload
                .pointer("/error/message")
                .and_then(Value::as_str)
                .unwrap_or("Anthropic stream returned an error");
            return Err(ModelError::Inference(message.to_string()));
        }
        _ => {}
    }
    Ok(())
}

fn finish_anthropic_stream(state: AnthropicStreamState) -> Value {
    let content = state
        .blocks
        .into_values()
        .map(|block| match block {
            AnthropicBlockStream::Text(text) => json!({"type":"text", "text":text}),
            AnthropicBlockStream::Tool { id, name, arguments } => {
                let input = serde_json::from_str::<Value>(&arguments).unwrap_or_else(|_| json!({}));
                json!({"type":"tool_use", "id":id, "name":name, "input":input})
            }
        })
        .collect::<Vec<_>>();
    normalize_anthropic_payload(json!({
        "id": state.id,
        "content": content,
        "usage": Value::Object(state.usage),
    }))
}

fn anthropic_messages(input: &Value) -> Vec<Value> {
    let mut messages: Vec<Value> = Vec::new();
    for item in input.as_array().into_iter().flatten() {
        if let Some(role) = item.get("role").and_then(Value::as_str) {
            if role == "system" {
                continue;
            }
            let content = item.get("content").cloned().unwrap_or_else(|| json!(""));
            let content = match content {
                Value::String(text) => json!([{"type":"text", "text":text}]),
                Value::Array(mut parts) => {
                    for part in &mut parts {
                        if matches!(
                            part.get("type").and_then(Value::as_str),
                            Some("input_text" | "output_text")
                        ) {
                            part["type"] = json!("text");
                        }
                    }
                    Value::Array(parts)
                }
                other => json!([{"type":"text", "text":other.to_string()}]),
            };
            messages.push(json!({"role": role, "content": content}));
            continue;
        }
        match item.get("type").and_then(Value::as_str) {
            Some("function_call") | Some("tool_call") => {
                let arguments = item
                    .get("arguments")
                    .or_else(|| item.pointer("/function/arguments"))
                    .cloned()
                    .unwrap_or_else(|| json!({}));
                let arguments = arguments
                    .as_str()
                    .and_then(|value| serde_json::from_str(value).ok())
                    .unwrap_or(arguments);
                let block = json!({
                    "type": "tool_use",
                    "id": item.get("call_id").or_else(|| item.get("id")).cloned().unwrap_or_else(|| json!("call")),
                    "name": item.get("name").or_else(|| item.pointer("/function/name")).cloned().unwrap_or_else(|| json!("tool")),
                    "input": arguments,
                });
                append_anthropic_content(&mut messages, "assistant", block);
            }
            Some("function_call_output") => {
                let content = item
                    .get("output")
                    .map(|value| match value {
                        Value::String(text) => text.clone(),
                        other => serde_json::to_string(other).unwrap_or_else(|_| "null".into()),
                    })
                    .unwrap_or_else(|| "null".into());
                let block = json!({
                    "type": "tool_result",
                    "tool_use_id": item.get("call_id").cloned().unwrap_or_else(|| json!("call")),
                    "content": content,
                });
                append_anthropic_content(&mut messages, "user", block);
            }
            _ => {}
        }
    }
    messages
}

fn anthropic_system(input: &Value, instructions: Option<&Value>) -> String {
    let mut sections = Vec::new();
    if let Some(value) = instructions.and_then(Value::as_str)
        && !value.trim().is_empty()
    {
        sections.push(value.trim().to_owned());
    }
    for item in input.as_array().into_iter().flatten() {
        if item.get("role").and_then(Value::as_str) != Some("system") {
            continue;
        }
        if let Some(value) = item.get("content").and_then(Value::as_str)
            && !value.trim().is_empty()
        {
            sections.push(value.trim().to_owned());
        }
    }
    sections.join("\n\n")
}

fn append_anthropic_content(messages: &mut Vec<Value>, role: &str, block: Value) {
    if let Some(content) = messages
        .last_mut()
        .filter(|message| message.get("role").and_then(Value::as_str) == Some(role))
        .and_then(|message| message.get_mut("content"))
        .and_then(Value::as_array_mut)
    {
        content.push(block);
    } else {
        messages.push(json!({"role": role, "content": [block]}));
    }
}

fn anthropic_tool(tool: &Value) -> Option<Value> {
    let name = tool.get("name").and_then(Value::as_str)?;
    Some(json!({
        "name": name,
        "description": tool.get("description").cloned().unwrap_or_else(|| json!("")),
        "input_schema": tool.get("parameters").cloned().unwrap_or_else(|| json!({"type":"object","properties":{}})),
    }))
}

fn normalize_anthropic_payload(payload: Value) -> Value {
    let mut output = Vec::new();
    for block in payload
        .get("content")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
    {
        match block.get("type").and_then(Value::as_str) {
            Some("text") => output.push(json!({
                "type": "message",
                "role": "assistant",
                "content": [{"type":"output_text", "text":block.get("text").cloned().unwrap_or_else(|| json!(""))}],
            })),
            Some("tool_use") => output.push(json!({
                "type": "function_call",
                "call_id": block.get("id").cloned().unwrap_or_else(|| json!("call")),
                "name": block.get("name").cloned().unwrap_or_else(|| json!("tool")),
                "arguments": serde_json::to_string(block.get("input").unwrap_or(&Value::Null)).unwrap_or_else(|_| "{}".into()),
            })),
            _ => {}
        }
    }
    let usage = payload.get("usage").cloned().unwrap_or(Value::Null);
    let uncached_input_tokens = usage
        .get("input_tokens")
        .and_then(Value::as_u64)
        .unwrap_or(0);
    let cache_creation_input_tokens = usage
        .get("cache_creation_input_tokens")
        .and_then(Value::as_u64)
        .unwrap_or(0);
    let input_tokens = uncached_input_tokens.saturating_add(cache_creation_input_tokens);
    let output_tokens = usage
        .get("output_tokens")
        .and_then(Value::as_u64)
        .unwrap_or(0);
    let cached_input_tokens = usage
        .get("cache_read_input_tokens")
        .and_then(Value::as_u64)
        .unwrap_or(0);
    json!({
        "id": payload.get("id").cloned().unwrap_or(Value::Null),
        "output": output,
        "usage": {
            "input_tokens": input_tokens,
            "cached_input_tokens": cached_input_tokens,
            "output_tokens": output_tokens,
            "total_tokens": input_tokens.saturating_add(cached_input_tokens).saturating_add(output_tokens),
        },
    })
}

fn chat_messages(input: &Value) -> Vec<Value> {
    let mut messages = Vec::new();
    for item in input.as_array().into_iter().flatten() {
        if let Some(role) = item.get("role").and_then(Value::as_str) {
            let content = item
                .get("content")
                .cloned()
                .unwrap_or(Value::String(String::new()));
            let content = if let Some(parts) = content.as_array() {
                Value::String(
                    parts
                        .iter()
                        .filter_map(|part| part.get("text").and_then(Value::as_str))
                        .collect::<Vec<_>>()
                        .join(""),
                )
            } else {
                content
            };
            messages.push(json!({"role": role, "content": content}));
            continue;
        }
        match item.get("type").and_then(Value::as_str) {
            Some("function_call") | Some("tool_call") => {
                let tool_call = json!({
                    "id": item.get("call_id").or_else(|| item.get("id")).cloned().unwrap_or_else(|| json!("call")),
                    "type": "function",
                    "function": {
                        "name": item.get("name").or_else(|| item.pointer("/function/name")).cloned().unwrap_or_else(|| json!("tool")),
                        "arguments": item.get("arguments").or_else(|| item.pointer("/function/arguments")).cloned().unwrap_or_else(|| json!("{}")),
                    }
                });
                if let Some(calls) = messages
                    .last_mut()
                    .filter(|message| {
                        message.get("role").and_then(Value::as_str) == Some("assistant")
                    })
                    .and_then(|message| message.get_mut("tool_calls"))
                    .and_then(Value::as_array_mut)
                {
                    calls.push(tool_call);
                } else {
                    messages.push(json!({
                        "role": "assistant",
                        "content": Value::Null,
                        "tool_calls": [tool_call]
                    }));
                }
            }
            Some("function_call_output") => messages.push(json!({
                "role": "tool",
                "tool_call_id": item.get("call_id").cloned().unwrap_or_else(|| json!("call")),
                "content": item.get("output").cloned().unwrap_or_else(|| json!("null")),
            })),
            _ => {}
        }
    }
    messages
}

fn chat_tool(tool: &Value) -> Option<Value> {
    let name = tool.get("name").and_then(Value::as_str)?;
    Some(json!({
        "type": "function",
        "function": {
            "name": name,
            "description": tool.get("description").cloned().unwrap_or_else(|| json!("")),
            "parameters": tool.get("parameters").cloned().unwrap_or_else(|| json!({"type":"object","properties":{}})),
        }
    }))
}

fn normalize_chat_payload(payload: Value) -> Value {
    let message = payload
        .pointer("/choices/0/message")
        .cloned()
        .unwrap_or(Value::Null);
    let mut output = Vec::new();
    if let Some(text) = message.get("content").and_then(Value::as_str)
        && !text.is_empty()
    {
        output.push(json!({"type":"message", "role":"assistant", "content":[{"type":"output_text", "text":text}]}));
    }
    for call in message
        .get("tool_calls")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
    {
        output.push(json!({
            "type": "function_call",
            "call_id": call.get("id").cloned().unwrap_or_else(|| json!("call")),
            "name": call.pointer("/function/name").cloned().unwrap_or_else(|| json!("tool")),
            "arguments": call.pointer("/function/arguments").cloned().unwrap_or_else(|| json!("{}")),
        }));
    }
    json!({
        "id": payload.get("id").cloned().unwrap_or(Value::Null),
        "output": output,
        "usage": payload.get("usage").cloned().unwrap_or(Value::Null),
    })
}

fn redacted_http_error(error: ureq::Error) -> ModelError {
    match error {
        ureq::Error::Status(status, response) => {
            let payload = response.into_json::<Value>().unwrap_or(Value::Null);
            let message = payload
                .pointer("/error/message")
                .or_else(|| payload.get("message"))
                .and_then(Value::as_str)
                .filter(|message| !message.trim().is_empty())
                .map(str::to_owned)
                .unwrap_or_else(|| format!("model endpoint returned HTTP {status}"));
            ModelError::Inference(message)
        }
        ureq::Error::Transport(error) => {
            ModelError::Inference(format!("model transport failed: {error}"))
        }
    }
}

pub fn extract_output_text(payload: &Value) -> Option<String> {
    if let Some(text) = payload.get("output_text").and_then(Value::as_str)
        && !text.is_empty()
    {
        return Some(text.to_string());
    }
    let output = payload.get("output").and_then(Value::as_array)?;
    let text = output
        .iter()
        .filter_map(|item| item.get("content").and_then(Value::as_array))
        .flatten()
        .filter_map(|content| content.get("text").and_then(Value::as_str))
        .collect::<Vec<_>>()
        .join("");
    (!text.is_empty()).then_some(text)
}

pub fn extract_usage(payload: &Value) -> Option<ModelUsage> {
    let usage = payload
        .get("usage")
        .or_else(|| payload.pointer("/response/usage"))?;
    let input_tokens = usage_value(usage, &["input_tokens", "prompt_tokens", "inputTokens"]);
    let output_tokens = usage_value(
        usage,
        &["output_tokens", "completion_tokens", "outputTokens"],
    );
    let cached_input_tokens = usage_value(usage, &["cached_input_tokens", "cachedInputTokens"])
        .max(
            usage
                .pointer("/input_tokens_details/cached_tokens")
                .and_then(Value::as_u64)
                .unwrap_or(0),
        );
    let reasoning_output_tokens =
        usage_value(usage, &["reasoning_output_tokens", "reasoningOutputTokens"]).max(
            usage
                .pointer("/output_tokens_details/reasoning_tokens")
                .and_then(Value::as_u64)
                .unwrap_or(0),
        );
    let total_tokens = usage_value(usage, &["total_tokens", "totalTokens"])
        .max(input_tokens.saturating_add(output_tokens));
    (total_tokens > 0).then_some(ModelUsage {
        total_tokens,
        input_tokens,
        cached_input_tokens,
        output_tokens,
        reasoning_output_tokens,
    })
}

fn usage_value(usage: &Value, keys: &[&str]) -> u64 {
    keys.iter()
        .find_map(|key| usage.get(*key).and_then(Value::as_u64))
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_text_and_usage_from_responses_payload() {
        let payload = json!({
            "output": [{"content": [{"type":"output_text", "text":"hello"}]}],
            "usage": {"input_tokens": 10, "output_tokens": 4, "total_tokens": 14}
        });
        assert_eq!(extract_output_text(&payload).as_deref(), Some("hello"));
        assert_eq!(
            extract_usage(&payload),
            Some(ModelUsage {
                total_tokens: 14,
                input_tokens: 10,
                cached_input_tokens: 0,
                output_tokens: 4,
                reasoning_output_tokens: 0,
            })
        );
    }

    #[test]
    fn remote_config_requires_https_and_rejects_header_injection() {
        let mut config = ResponsesModelConfig {
            base_url: "http://example.test/v1".into(),
            default_model: "model".into(),
            bearer_token: None,
            provider_mode: ModelProviderMode::FirstPartyDacheng,
            wire_api: ResponsesWireApi::Responses,
        };
        assert!(config.validate().is_err());
        config.base_url = "https://example.test/v1".into();
        config.bearer_token = Some("token\nheader".into());
        assert!(config.validate().is_err());
    }

    #[test]
    fn normalizes_chat_completion_text_tools_and_usage() {
        let normalized = normalize_chat_payload(json!({
            "id":"chat-1",
            "choices":[{"message":{"role":"assistant","content":"善哉","tool_calls":[{"id":"call-1","type":"function","function":{"name":"search","arguments":"{\"q\":\"法\"}"}}]}}],
            "usage":{"prompt_tokens":12,"completion_tokens":4,"total_tokens":16}
        }));
        assert_eq!(extract_output_text(&normalized).as_deref(), Some("善哉"));
        assert_eq!(normalized["output"][1]["name"], "search");
        assert_eq!(extract_usage(&normalized).unwrap().total_tokens, 16);
    }

    #[test]
    fn groups_adjacent_tool_calls_into_one_assistant_message() {
        let messages = chat_messages(&json!([
            {"role":"user", "content":"search"},
            {"type":"function_call", "call_id":"call-1", "name":"first", "arguments":"{}"},
            {"type":"function_call", "call_id":"call-2", "name":"second", "arguments":"{}"},
            {"type":"function_call_output", "call_id":"call-1", "output":"one"},
            {"type":"function_call_output", "call_id":"call-2", "output":"two"}
        ]));
        assert_eq!(messages.len(), 4);
        assert_eq!(messages[1]["tool_calls"].as_array().unwrap().len(), 2);
    }

    #[test]
    fn normalizes_anthropic_text_tools_and_cache_usage() {
        let normalized = normalize_anthropic_payload(json!({
            "id":"msg-1",
            "content":[
                {"type":"text","text":"善哉"},
                {"type":"tool_use","id":"tool-1","name":"search","input":{"q":"法"}}
            ],
            "usage":{"input_tokens":10,"cache_creation_input_tokens":2,"cache_read_input_tokens":4,"output_tokens":3}
        }));
        assert_eq!(extract_output_text(&normalized).as_deref(), Some("善哉"));
        assert_eq!(normalized["output"][1]["name"], "search");
        assert_eq!(extract_usage(&normalized).unwrap().input_tokens, 12);
        assert_eq!(extract_usage(&normalized).unwrap().cached_input_tokens, 4);
        assert_eq!(extract_usage(&normalized).unwrap().total_tokens, 19);
    }

    #[test]
    fn groups_anthropic_text_with_tool_use_and_serializes_tool_results() {
        let messages = anthropic_messages(&json!([
            {"role":"user", "content":"search"},
            {"role":"assistant", "content":"I will search."},
            {"type":"function_call", "call_id":"tool-1", "name":"search", "arguments":"{\"q\":\"法\"}"},
            {"type":"function_call_output", "call_id":"tool-1", "output":{"ok":true}}
        ]));
        assert_eq!(messages.len(), 3);
        assert_eq!(messages[1]["content"].as_array().unwrap().len(), 2);
        assert_eq!(messages[2]["content"][0]["content"], "{\"ok\":true}");
    }

    #[derive(Default)]
    struct RecordingSink {
        events: std::sync::Mutex<Vec<ModelEvent>>,
    }

    impl crate::ModelEventSink for RecordingSink {
        fn emit(&self, event: ModelEvent) -> Result<(), ModelError> {
            self.events.lock().expect("record model event").push(event);
            Ok(())
        }
    }

    fn recorded_deltas(sink: &RecordingSink) -> Vec<String> {
        sink.events
            .lock()
            .expect("read model events")
            .iter()
            .filter_map(|event| match event {
                ModelEvent::OutputTextDelta(delta) => Some(delta.clone()),
                _ => None,
            })
            .collect()
    }

    #[test]
    fn responses_sse_emits_multiple_deltas_before_completion() {
        let stream = concat!(
            r#"data: {"type":"response.output_text.delta","delta":"你"}"#, "\n\n",
            r#"data: {"type":"response.output_text.delta","delta":"好"}"#, "\n\n",
            r#"data: {"type":"response.completed","response":{"id":"resp-1","output":[{"type":"message","role":"assistant","content":[{"type":"output_text","text":"你好"}]}],"usage":{"input_tokens":2,"output_tokens":2,"total_tokens":4}}}"#, "\n\n",
            "data: [DONE]\n\n",
        );
        let sink = std::sync::Arc::new(RecordingSink::default());
        let shared: SharedModelEventSink = sink.clone();
        let payload = parse_sse_response(
            ResponsesWireApi::Responses,
            std::io::Cursor::new(stream.as_bytes()),
            &shared,
        )
        .expect("parse Responses stream");
        assert_eq!(recorded_deltas(&sink), vec!["你", "好"]);
        assert_eq!(extract_output_text(&payload).as_deref(), Some("你好"));
        assert_eq!(extract_usage(&payload).expect("usage").total_tokens, 4);
    }

    #[test]
    fn chat_completion_sse_reassembles_text_tool_calls_and_usage() {
        let stream = concat!(
            r#"data: {"id":"chat-1","choices":[{"delta":{"content":"查"}}]}"#, "\n\n",
            r#"data: {"id":"chat-1","choices":[{"delta":{"content":"询","tool_calls":[{"index":0,"id":"call-1","function":{"name":"search","arguments":"{\"q\":"}}]}}]}"#, "\n\n",
            r#"data: {"id":"chat-1","choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\"法\"}"}}]}}],"usage":{"prompt_tokens":3,"completion_tokens":2,"total_tokens":5}}"#, "\n\n",
            "data: [DONE]\n\n",
        );
        let sink = std::sync::Arc::new(RecordingSink::default());
        let shared: SharedModelEventSink = sink.clone();
        let payload = parse_sse_response(
            ResponsesWireApi::ChatCompletions,
            std::io::Cursor::new(stream.as_bytes()),
            &shared,
        )
        .expect("parse chat stream");
        assert_eq!(recorded_deltas(&sink), vec!["查", "询"]);
        assert_eq!(extract_output_text(&payload).as_deref(), Some("查询"));
        assert_eq!(payload["output"][1]["name"], "search");
        assert_eq!(payload["output"][1]["arguments"], "{\"q\":\"法\"}");
        assert_eq!(extract_usage(&payload).expect("usage").total_tokens, 5);
    }

    #[test]
    fn anthropic_sse_emits_text_deltas_and_preserves_usage() {
        let stream = concat!(
            "event: message_start\n", r#"data: {"type":"message_start","message":{"id":"msg-1","usage":{"input_tokens":4}}}"#, "\n\n",
            "event: content_block_start\n", r#"data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#, "\n\n",
            "event: content_block_delta\n", r#"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"善"}}"#, "\n\n",
            "event: content_block_delta\n", r#"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"哉"}}"#, "\n\n",
            "event: message_delta\n", r#"data: {"type":"message_delta","usage":{"output_tokens":2}}"#, "\n\n",
            "event: message_stop\n", r#"data: {"type":"message_stop"}"#, "\n\n",
        );
        let sink = std::sync::Arc::new(RecordingSink::default());
        let shared: SharedModelEventSink = sink.clone();
        let payload = parse_sse_response(
            ResponsesWireApi::AnthropicMessages,
            std::io::Cursor::new(stream.as_bytes()),
            &shared,
        )
        .expect("parse Anthropic stream");
        assert_eq!(recorded_deltas(&sink), vec!["善", "哉"]);
        assert_eq!(extract_output_text(&payload).as_deref(), Some("善哉"));
        assert_eq!(extract_usage(&payload).expect("usage").total_tokens, 6);
    }

}
