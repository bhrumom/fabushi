use codex_wrapper::{CodexClient, CodexConfig, CodexEvent, CodexModelConfig, ModelProviderType};
use futures::stream::StreamExt;
use serde_json::json;

#[tokio::test]
async fn test_universal_sdk_bot_father_closed_loop() {
    // 1. 模拟配置为大乘后端托管的 DeepSeek 大脑
    let model_cfg = CodexModelConfig::deepseek("test_key_123");
    assert_eq!(model_cfg.provider, ModelProviderType::DeepSeek);
    assert_eq!(
        model_cfg.base_url,
        "https://api.ombhrum.com/api/openclaw/deepseek/v1"
    );
    assert_eq!(model_cfg.api_key, "dacheng-openclaw-proxy");
    assert_eq!(
        model_cfg.custom_headers.get("x-dacheng-auth-token"),
        Some(&"test_key_123".to_string())
    );
    assert_eq!(model_cfg.model_name, "deepseek-chat");

    // 2. 创建统一 CodexClient 并绑定沙盒
    let client = CodexClient::new(CodexConfig::default().with_model(model_cfg));
    let vfs = client.get_vfs();

    // 3. 机器人之父创建小程序定制开发会话
    let thread = client
        .create_thread("你是机器人之父，请直接使用沙盒工具编写小程序。")
        .await
        .expect("Failed to create thread");

    // 4. 模拟向会话底层传入 OpenAI/DeepSeek 兼容的 SSE 流式分片数据
    if let Some(mock_tx) = thread.mock_tx.clone() {
        tokio::spawn(async move {
            // 模拟第一片：思考流 reasoning_content
            let chunk_reason = json!({
                "choices": [{
                    "delta": {
                        "reasoning_content": "用户需要打卡日记小程序，我首先创建 manifest.json 和 index.tsx"
                    }
                }]
            });
            mock_tx
                .send(format!("data: {}", chunk_reason.to_string()))
                .await
                .unwrap();

            // 模拟第二片：触发 create_file 工具调用创建 index.tsx
            let chunk_tool_create = json!({
                "choices": [{
                    "delta": {
                        "tool_calls": [{
                            "function": {
                                "name": "create_file",
                                "arguments": "{\"path\": \"index.tsx\", \"content\": \"export default function App() { return <div id='title'>早安签到</div>; }\"}"
                            }
                        }]
                    }
                }]
            });
            mock_tx
                .send(format!("data: {}", chunk_tool_create.to_string()))
                .await
                .unwrap();

            // 模拟第三片：触发 patch_code 工具调用修改样式
            let chunk_tool_patch = json!({
                "choices": [{
                    "delta": {
                        "tool_calls": [{
                            "function": {
                                "name": "patch_code",
                                "arguments": "{\"path\": \"index.tsx\", \"find_str\": \"早安签到\", \"replace_str\": \"莫兰迪禅修日记\"}"
                            }
                        }]
                    }
                }]
            });
            mock_tx
                .send(format!("data: {}", chunk_tool_patch.to_string()))
                .await
                .unwrap();

            // 模拟流结束
            mock_tx.send("data: [DONE]".to_string()).await.unwrap();
        });
    }

    // 5. 调用会话发消息并监听结构化事件流
    let mut stream = thread
        .send_message("帮我做莫兰迪打卡日记小程序")
        .await
        .expect("Failed to send message");

    let mut reasoning_received = false;
    let mut file_created = false;
    let mut file_patched = false;

    while let Some(event) = stream.next().await {
        match event {
            CodexEvent::ReasoningProgress { content } => {
                if content.contains("manifest.json") {
                    reasoning_received = true;
                }
            }
            CodexEvent::SandboxFileModified {
                file_path,
                new_content,
            } => {
                if file_path == "index.tsx" {
                    if new_content.contains("早安签到") {
                        file_created = true;
                    }
                    if new_content.contains("莫兰迪禅修日记") {
                        file_patched = true;
                    }
                }
            }
            _ => {}
        }
    }

    // 6. 自动回归验证所有核心业务步骤
    assert!(
        reasoning_received,
        "Should receive DeepSeek reasoning content"
    );
    assert!(
        file_created,
        "Should receive SandboxFileModified for index.tsx creation"
    );
    assert!(
        file_patched,
        "Should receive SandboxFileModified for patch_code modification"
    );

    // 7. 自动校验虚拟文件系统 VFS 最终的内容正确性
    let content_in_vfs = vfs
        .read_file("index.tsx")
        .expect("File should exist in VFS");
    assert!(
        content_in_vfs.contains("莫兰迪禅修日记"),
        "VFS content should match patched version"
    );
}
