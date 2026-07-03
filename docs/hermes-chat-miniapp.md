# Hermes 聊天式安装小程序

这个小程序把 Hermes Agent 的终端安装和首次配置变成聊天流程：

```text
用户在小程序回复数字
  -> 小程序收集安装方式、模型、API key、目录
  -> 本机 Host 启动 Hermes 安装命令
  -> stdout/stderr 回写成聊天消息
  -> 用户继续在聊天框回复安装器问题
  -> 安装完成后，同一聊天框转为 Hermes 对话
```

## 启动本机 Host

在仓库根目录运行：

```bash
node scripts/hermes-chat-host.mjs
```

默认监听：

```text
http://127.0.0.1:17393
```

默认安装命令来自 Hermes Agent 官方安装方式：

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
hermes setup --portal
```

Windows 会使用：

```powershell
iex (irm https://hermes-agent.nousresearch.com/install.ps1)
```

## 可选环境变量

```bash
HERMES_HOST_PORT=17393
HERMES_HOST_BIND=127.0.0.1
HERMES_INSTALL_COMMAND='curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash'
HERMES_CHAT_COMMAND='hermes'
HERMES_CHAT_TIMEOUT_MS=90000
HERMES_CHAT_IDLE_MS=1400
```

## 小程序入口

- Web 官方小程序：`/miniapps/official.hermes-installer`
- 微信小程序页面：`/pages/hermes/index`

宿主的职责只是代理本机进程输入输出；安装流程、配置状态机和 Hermes 对话都由小程序发起并呈现在聊天框里。
