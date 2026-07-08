use anyhow::Result;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::HashMap;

/// 支持的大模型提供商枚举
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum ModelProviderType {
    OpenAI,
    DeepSeek,
    AnthropicClaude,
    GoogleGemini,
    LocalOllama,
    CustomServer,
}

/// 传递给 SDK 的运行时大模型配置
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CodexModelConfig {
    pub provider: ModelProviderType,
    pub base_url: String,
    pub api_key: String,
    pub model_name: String,
    pub temperature: f32,
    pub custom_headers: HashMap<String, String>,
}

impl Default for CodexModelConfig {
    fn default() -> Self {
        Self::deepseek("")
    }
}

impl CodexModelConfig {
    pub fn deepseek(auth_token: impl Into<String>) -> Self {
        let auth_token = auth_token.into();
        let mut custom_headers = HashMap::new();
        if !auth_token.trim().is_empty() && auth_token != "dacheng-openclaw-proxy" {
            custom_headers.insert("x-dacheng-auth-token".to_string(), auth_token);
        }
        Self {
            provider: ModelProviderType::DeepSeek,
            base_url: "https://api.ombhrum.com/api/openclaw/deepseek/v1".to_string(),
            api_key: "dacheng-openclaw-proxy".to_string(),
            model_name: "deepseek-chat".to_string(),
            temperature: 0.1,
            custom_headers,
        }
    }

    pub fn ollama(model_name: impl Into<String>) -> Self {
        Self {
            provider: ModelProviderType::LocalOllama,
            base_url: "http://localhost:11434/v1".to_string(),
            api_key: "ollama".to_string(),
            model_name: model_name.into(),
            temperature: 0.1,
            custom_headers: HashMap::new(),
        }
    }
}

/// Codex 工具定义 Schema
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ToolDefinition {
    pub name: String,
    pub description: String,
    pub parameters_schema: Value,
}

/// Codex 标准结构化事件流
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CodexEvent {
    ReasoningProgress {
        content: String,
    },
    ToolCallTriggered {
        tool_name: String,
        arguments: Value,
    },
    SandboxFileModified {
        file_path: String,
        new_content: String,
    },
    TurnCompleted {
        summary: String,
    },
    Error {
        message: String,
    },
}

/// 模型协议转译网关：使第三方大模型融入 Codex 智能体协议
pub trait CodexModelGateway: Send + Sync {
    /// 将系统提示词与工具 Schema 转化为目标大模型的 JSON 结构
    fn format_request(
        &self,
        prompt: &str,
        tools: &[ToolDefinition],
        config: &CodexModelConfig,
    ) -> String;
    /// 将流式响应解析还原为 CodexEvent 事件
    fn parse_stream_chunk(
        &self,
        raw_chunk: &str,
        provider: &ModelProviderType,
    ) -> Result<Vec<CodexEvent>>;
}

pub struct UniversalModelGateway;

impl Default for UniversalModelGateway {
    fn default() -> Self {
        Self::new()
    }
}

impl UniversalModelGateway {
    pub fn new() -> Self {
        Self
    }
}

impl CodexModelGateway for UniversalModelGateway {
    fn format_request(
        &self,
        prompt: &str,
        tools: &[ToolDefinition],
        config: &CodexModelConfig,
    ) -> String {
        match config.provider {
            ModelProviderType::OpenAI
            | ModelProviderType::DeepSeek
            | ModelProviderType::LocalOllama
            | ModelProviderType::CustomServer => {
                let formatted_tools: Vec<Value> = tools
                    .iter()
                    .map(|t| {
                        json!({
                            "type": "function",
                            "function": {
                                "name": t.name,
                                "description": t.description,
                                "parameters": t.parameters_schema
                            }
                        })
                    })
                    .collect();

                let body = json!({
                    "model": config.model_name,
                    "temperature": config.temperature,
                    "messages": [
                        { "role": "user", "content": prompt }
                    ],
                    "tools": formatted_tools,
                    "stream": true
                });
                body.to_string()
            }
            ModelProviderType::AnthropicClaude => {
                let formatted_tools: Vec<Value> = tools
                    .iter()
                    .map(|t| {
                        json!({
                            "name": t.name,
                            "description": t.description,
                            "input_schema": t.parameters_schema
                        })
                    })
                    .collect();

                let body = json!({
                    "model": config.model_name,
                    "max_tokens": 4096,
                    "temperature": config.temperature,
                    "messages": [
                        { "role": "user", "content": prompt }
                    ],
                    "tools": formatted_tools,
                    "stream": true
                });
                body.to_string()
            }
            ModelProviderType::GoogleGemini => {
                let formatted_tools: Vec<Value> = tools
                    .iter()
                    .map(|t| {
                        json!({
                            "name": t.name,
                            "description": t.description,
                            "parameters": t.parameters_schema
                        })
                    })
                    .collect();

                let body = json!({
                    "contents": [
                        { "role": "user", "parts": [{ "text": prompt }] }
                    ],
                    "tools": [{ "functionDeclarations": formatted_tools }]
                });
                body.to_string()
            }
        }
    }

    fn parse_stream_chunk(
        &self,
        raw_chunk: &str,
        provider: &ModelProviderType,
    ) -> Result<Vec<CodexEvent>> {
        let mut events = Vec::new();
        let trimmed = raw_chunk.trim();
        if trimmed.is_empty() || trimmed == "[DONE]" {
            return Ok(events);
        }

        // 处理 SSE data: 格式
        let payload = if let Some(stripped) = trimmed.strip_prefix("data: ") {
            stripped.trim()
        } else {
            trimmed
        };

        if payload == "[DONE]" {
            events.push(CodexEvent::TurnCompleted {
                summary: "Stream finished successfully".to_string(),
            });
            return Ok(events);
        }

        if let Ok(val) = serde_json::from_str::<Value>(payload) {
            match provider {
                ModelProviderType::OpenAI
                | ModelProviderType::DeepSeek
                | ModelProviderType::LocalOllama => {
                    // 解析 OpenAI 兼容的工具调用与思考过程
                    if let Some(choices) = val.get("choices").and_then(|c| c.as_array()) {
                        for choice in choices {
                            if let Some(delta) = choice.get("delta") {
                                // DeepSeek 推理内容字段 reasoning_content
                                if let Some(reasoning) =
                                    delta.get("reasoning_content").and_then(|r| r.as_str())
                                {
                                    if !reasoning.is_empty() {
                                        events.push(CodexEvent::ReasoningProgress {
                                            content: reasoning.to_string(),
                                        });
                                    }
                                }
                                // 常规回复内容
                                if let Some(content) = delta.get("content").and_then(|c| c.as_str())
                                {
                                    if !content.is_empty() {
                                        events.push(CodexEvent::ReasoningProgress {
                                            content: content.to_string(),
                                        });
                                    }
                                }
                                // 工具调用 tool_calls
                                if let Some(tool_calls) =
                                    delta.get("tool_calls").and_then(|tc| tc.as_array())
                                {
                                    for tc in tool_calls {
                                        if let Some(func) = tc.get("function") {
                                            if let (Some(name), Some(args_str)) = (
                                                func.get("name").and_then(|n| n.as_str()),
                                                func.get("arguments").and_then(|a| a.as_str()),
                                            ) {
                                                let args_val = serde_json::from_str(args_str)
                                                    .unwrap_or_else(|_| json!({ "raw": args_str }));
                                                events.push(CodexEvent::ToolCallTriggered {
                                                    tool_name: name.to_string(),
                                                    arguments: args_val,
                                                });
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                ModelProviderType::AnthropicClaude => {
                    if let Some(type_str) = val.get("type").and_then(|t| t.as_str()) {
                        if type_str == "content_block_start" {
                            if let Some(block) = val.get("content_block") {
                                if block.get("type").and_then(|t| t.as_str()) == Some("tool_use") {
                                    let name = block
                                        .get("name")
                                        .and_then(|n| n.as_str())
                                        .unwrap_or("unknown");
                                    let input = block.get("input").cloned().unwrap_or(json!({}));
                                    events.push(CodexEvent::ToolCallTriggered {
                                        tool_name: name.to_string(),
                                        arguments: input,
                                    });
                                }
                            }
                        }
                    }
                }
                ModelProviderType::GoogleGemini => {
                    if let Some(candidates) = val.get("candidates").and_then(|c| c.as_array()) {
                        for cand in candidates {
                            if let Some(parts) = cand
                                .get("content")
                                .and_then(|c| c.get("parts"))
                                .and_then(|p| p.as_array())
                            {
                                for part in parts {
                                    if let Some(fc) = part.get("functionCall") {
                                        let name = fc
                                            .get("name")
                                            .and_then(|n| n.as_str())
                                            .unwrap_or("unknown");
                                        let args = fc.get("args").cloned().unwrap_or(json!({}));
                                        events.push(CodexEvent::ToolCallTriggered {
                                            tool_name: name.to_string(),
                                            arguments: args,
                                        });
                                    }
                                }
                            }
                        }
                    }
                }
                _ => {}
            }
        }

        Ok(events)
    }
}
