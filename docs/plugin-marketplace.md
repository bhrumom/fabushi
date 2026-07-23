# 大乘 CLI 插件市场

## 发现入口

官方市场清单提供两个入口：

- 内置桌面/CLI bundle：`.agents/plugins/marketplace.json`
- 公共发现端点：`/.well-known/mahayana/marketplace.json`

客户端应优先读取内置清单；需要远端更新时读取公共清单并校验版本。

## 安装流程

1. 下载对应平台插件构件。
2. 校验 `.sha256`。
3. 解压到 Mahayana plugin store。
4. 检查 `.codex-plugin/plugin.json`、`.mahayana/plugin.json` 与 `.mcp.json` 契约。
5. 优先启动 `runtime/cli/fabushi-plugin-cli`，不可用时使用 HTTP MCP 变体。

## 运行时契约

每个官方插件必须提供：

- Codex manifest
- Mahayana runtime manifest
- MCP server 配置
- cli/desktop/mobile/web runtimeVariants
- 可发现的小程序主页资源

## 发布验证

GitHub Actions 负责构建、打包、安装验证和发布证据；本地环境只用于代码检查。
