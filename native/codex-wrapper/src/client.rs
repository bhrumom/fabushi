use crate::model::{
    CodexEvent, CodexModelConfig, CodexModelGateway, ToolDefinition, UniversalModelGateway,
};
use crate::sandbox::VirtualVfs;
use crate::transport::{CodexTransport, InProcessMemoryTransport};
use anyhow::Result;
use futures::stream::{BoxStream, StreamExt};
use serde_json::json;
use std::sync::Arc;
use tokio::sync::Mutex;

/// SDK 客户端主配置项
#[derive(Debug, Clone)]
pub struct CodexConfig {
    pub model: CodexModelConfig,
    pub workspace_id: String,
    pub vfs: Arc<VirtualVfs>,
}

impl Default for CodexConfig {
    fn default() -> Self {
        Self {
            model: CodexModelConfig::default(),
            workspace_id: "default_workspace".to_string(),
            vfs: Arc::new(VirtualVfs::new()),
        }
    }
}

impl CodexConfig {
    pub fn with_model(mut self, model: CodexModelConfig) -> Self {
        self.model = model;
        self
    }

    pub fn with_workspace(mut self, workspace_id: impl Into<String>) -> Self {
        self.workspace_id = workspace_id.into();
        self
    }
}

/// 统一 Codex 客户端对象：负责全平台初始化调用与会话线程管理
pub struct CodexClient {
    config: CodexConfig,
    gateway: Arc<dyn CodexModelGateway>,
}

impl CodexClient {
    pub fn new(config: CodexConfig) -> Self {
        Self {
            config,
            gateway: Arc::new(UniversalModelGateway::new()),
        }
    }

    pub fn get_vfs(&self) -> Arc<VirtualVfs> {
        self.config.vfs.clone()
    }

    /// 创建一个与 Codex 智能体的会话线程
    pub async fn create_thread(
        &self,
        system_prompt: impl Into<String>,
    ) -> Result<WorkspaceThread> {
        // 默认提供通用的文件沙盒操作工具集 Schema
        let tools = vec![
            ToolDefinition {
                name: "create_file".to_string(),
                description: "Create or replace a file in the virtual sandbox".to_string(),
                parameters_schema: json!({
                    "type": "object",
                    "properties": {
                        "path": { "type": "string", "description": "Relative file path" },
                        "content": { "type": "string", "description": "Full source code content" }
                    },
                    "required": ["path", "content"]
                }),
            },
            ToolDefinition {
                name: "patch_code".to_string(),
                description: "Modify an existing file by replacing target string".to_string(),
                parameters_schema: json!({
                    "type": "object",
                    "properties": {
                        "path": { "type": "string" },
                        "find_str": { "type": "string" },
                        "replace_str": { "type": "string" }
                    },
                    "required": ["path", "find_str", "replace_str"]
                }),
            },
        ];

        // 默认在移动端或测试环境下使用内联驱动
        let (transport, tx_in, rx_out) = InProcessMemoryTransport::new();

        Ok(WorkspaceThread {
            workspace_id: self.config.workspace_id.clone(),
            system_prompt: system_prompt.into(),
            config: self.config.model.clone(),
            vfs: self.config.vfs.clone(),
            gateway: self.gateway.clone(),
            tools,
            transport: Arc::new(Mutex::new(Box::new(transport))),
            mock_tx: Some(tx_in),
            mock_rx: Some(rx_out),
        })
    }
}

/// 智能体工作区会话线程
pub struct WorkspaceThread {
    pub workspace_id: String,
    pub system_prompt: String,
    pub config: CodexModelConfig,
    pub vfs: Arc<VirtualVfs>,
    pub gateway: Arc<dyn CodexModelGateway>,
    pub tools: Vec<ToolDefinition>,
    pub transport: Arc<Mutex<Box<dyn CodexTransport>>>,
    pub mock_tx: Option<tokio::sync::mpsc::Sender<String>>,
    pub mock_rx: Option<tokio::sync::mpsc::Receiver<String>>,
}

impl WorkspaceThread {
    /// 向 Codex 发送用户对话指令，并返回异步的结构化事件流
    pub async fn send_message(&self, user_prompt: &str) -> Result<BoxStream<'static, CodexEvent>> {
        let full_prompt = format!("{}\nUser: {}", self.system_prompt, user_prompt);
        let payload = self
            .gateway
            .format_request(&full_prompt, &self.tools, &self.config);

        {
            let mut guard = self.transport.lock().await;
            guard.send_message(payload).await?;
        }

        // 获取底层实时事件分片通道
        let mut guard = self.transport.lock().await;
        let mut raw_stream = guard.receive_stream().await?;

        let gateway = self.gateway.clone();
        let provider = self.config.provider.clone();
        let vfs = self.vfs.clone();

        let event_stream = async_stream::stream! {
            'stream_loop: while let Some(res) = raw_stream.next().await {
                match res {
                    Ok(chunk) => {
                        if let Ok(events) = gateway.parse_stream_chunk(&chunk, &provider) {
                            for event in events {
                                let is_done = matches!(event, CodexEvent::TurnCompleted { .. });
                                // 如果触发了工具调用，自动响应并操作沙盒
                                if let CodexEvent::ToolCallTriggered { ref tool_name, ref arguments } = event {
                                    if tool_name == "create_file" || tool_name == "update_file" {
                                        if let (Some(path), Some(content)) = (
                                            arguments.get("path").and_then(|p| p.as_str()),
                                            arguments.get("content").and_then(|c| c.as_str()),
                                        ) {
                                            let _ = vfs.create_file(path, content);
                                            yield CodexEvent::SandboxFileModified {
                                                file_path: path.to_string(),
                                                new_content: content.to_string(),
                                            };
                                        }
                                    } else if tool_name == "patch_code" {
                                        if let (Some(path), Some(find_str), Some(rep_str)) = (
                                            arguments.get("path").and_then(|p| p.as_str()),
                                            arguments.get("find_str").and_then(|f| f.as_str()),
                                            arguments.get("replace_str").and_then(|r| r.as_str()),
                                        ) {
                                            if vfs.patch_code(path, find_str, rep_str).is_ok() {
                                                if let Ok(new_content) = vfs.read_file(path) {
                                                    yield CodexEvent::SandboxFileModified {
                                                        file_path: path.to_string(),
                                                        new_content,
                                                    };
                                                }
                                            }
                                        }
                                    }
                                }
                                yield event;
                                if is_done {
                                    break 'stream_loop;
                                }
                            }
                        }
                    }
                    Err(e) => {
                        yield CodexEvent::Error {
                            message: format!("Transport error: {}", e),
                        };
                        break 'stream_loop;
                    }
                }
            }
        };

        Ok(Box::pin(event_stream))
    }
}
