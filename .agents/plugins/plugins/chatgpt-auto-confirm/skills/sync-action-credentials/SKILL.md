---
name: sync-action-credentials
description: 从当前 ChatGPT 桌面应用的真实网页 Chat renderer 实时抓取会话，验证其与本机 Codex 属于同一账号，再安全同步到 GitHub Actions Secrets；可选择立即启动自动确认 Action。用户要求更新、刷新、重新保存或一键同步云端 ChatGPT 凭证时使用。
---

# 一键同步 Action 凭证

使用自动确认小程序的 `sync_actions_credentials` 命令完成同步；不要自行读取、打印或复制凭证明文。

## 流程

1. 调用 `sync_actions_credentials`。需要同步后立即启动云端运行器时传入 `{ "start": true, "waitSeconds": 600 }`；只更新密钥时传入 `{ "start": false, "waitSeconds": 600 }`。
2. 命令打开或复用桌面应用中的 `https://chatgpt.com` renderer，并通过 `/api/auth/session` 验证网页会话；不得把 Work/Codex 的 `app://` 页面当作网页 Chat 登录。
3. 将网页会话返回的用户/账号 ID 与 `~/.codex/auth.json` 中的 Codex 身份比对。未登录或账号不一致时停止，不上传任何凭证。
4. 验证成功后，立即通过 CDP `Network.getAllCookies` 抓取当前 renderer 的 Cookie，规范化后原子写入本机私有 `session-cookies.json`。
5. 使用 `base64` 管道向 `gh secret set` 同步 Codex 凭证、刚抓取的 ChatGPT 会话和队列初始状态；不得复用未验证的旧 Cookie 文件。
6. 仅返回非敏感摘要：是否成功、仓库、写入的 Secret 名称、Cookie 数量和账号已验证状态；绝不返回 token、Cookie、auth 文件内容、账号 ID 或 Base64 值。

## 目标 Secrets

- `CHATGPT_CODEX_AUTH_B64`
- `CHATGPT_SESSION_COOKIES_B64`
- 可选的队列状态密钥：`CHATGPT_AUTO_CONFIRM_INITIAL_STATE_B64`、`CHATGPT_AUTO_CONFIRM_STATE_KEY`

## 安全边界

- 必须经过宿主的显式授权卡；skill 不绕过用户确认。
- 不读取 GitHub Secret 明文，也不在日志、聊天或错误信息中输出凭证。
- 每次命令都必须重新验证并实时抓取当前网页 Chat renderer；现有 `session-cookies.json` 只能作为成功抓取后的输出，不能作为上传来源。
- 未登录时允许打开登录入口并等待用户完成登录；账号不一致时立即失败，禁止覆盖 GitHub Secret。
- 每次都会更新 `CHATGPT_CODEX_AUTH_B64`、`CHATGPT_SESSION_COOKIES_B64` 和 `CHATGPT_AUTO_CONFIRM_INITIAL_STATE_B64`；仅当不存在时生成 `CHATGPT_AUTO_CONFIRM_STATE_KEY`。
- 同步失败时只报告阶段性错误和下一步，不尝试把凭证写入普通文件、Issue、PR 或任务 prompt。
