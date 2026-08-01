---
name: sync-action-credentials
description: 将当前已登录且已验证为同一账号的 ChatGPT/Codex 凭证安全同步到 GitHub Actions Secrets，并可选择立即启动自动确认 Action。用户要求更新、刷新、重新保存或一键同步云端凭证时使用。
---

# 一键同步 Action 凭证

使用自动确认小程序的 `sync_actions_credentials` 命令完成同步；不要自行读取、打印或复制凭证明文。

## 流程

1. 确认本机存在以下文件；本流程不会重新抓取浏览器 renderer：
   - `~/.codex/auth.json`
   - `~/Library/Application Support/Mahayana/plugins/chatgpt-auto-confirm/session-cookies.json`
   - `~/Library/Application Support/Mahayana/plugins/chatgpt-auto-confirm/queue-state.json`
2. 调用 `sync_actions_credentials`。需要同步后立即启动云端运行器时传入 `{ "start": true }`；只更新密钥时传入 `{ "start": false }`。
3. 宿主读取上述本机文件，使用 `base64` 管道传给 `gh secret set`；登录或账号校验由 `login_and_sync_actions` 负责。
4. 仅返回非敏感摘要：是否成功、仓库、写入的 Secret 名称和 cookie 数量；绝不返回 token、cookie、auth 文件内容或 Base64 值。
5. 如果需要登录或账号不一致，改用 `login_and_sync_actions`，让用户完成登录后再同步。

## 目标 Secrets

- `CHATGPT_CODEX_AUTH_B64`
- `CHATGPT_SESSION_COOKIES_B64`
- 可选的队列状态密钥：`CHATGPT_AUTO_CONFIRM_INITIAL_STATE_B64`、`CHATGPT_AUTO_CONFIRM_STATE_KEY`

## 安全边界

- 必须经过宿主的显式授权卡；skill 不绕过用户确认。
- 不读取 GitHub Secret 明文，也不在日志、聊天或错误信息中输出凭证。
- 只有此前已经完成账号验证的本机凭证文件才应使用本命令；账号不一致时先运行 `login_and_sync_actions`。
- 每次都会更新 `CHATGPT_CODEX_AUTH_B64`、`CHATGPT_SESSION_COOKIES_B64` 和 `CHATGPT_AUTO_CONFIRM_INITIAL_STATE_B64`；仅当不存在时生成 `CHATGPT_AUTO_CONFIRM_STATE_KEY`。
- 同步失败时只报告阶段性错误和下一步，不尝试把凭证写入普通文件、Issue、PR 或任务 prompt。
