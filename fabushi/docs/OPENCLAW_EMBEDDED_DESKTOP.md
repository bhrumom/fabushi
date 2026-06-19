# 大乘桌面版内置 OpenClaw 集成说明

## 目标

本补丁不新增底部 Tab，也不改变首页对话入口。用户在桌面版首页输入“问问 AI”时，原有 UI 仍然调用 `DachengAiService`，但服务层会自动路由到 App 内置的本机 OpenClaw Gateway。移动端与 Web 继续使用现有线上 API。

## 运行链路

```text
首页 AI 输入框
  -> DachengAiService
    -> 桌面端: OpenClawAiBridge
       -> OpenClawRuntime 自动释放 assets/openclaw/<platform>
       -> 启动 127.0.0.1:18789 OpenClaw Gateway
       -> POST /v1/chat/completions model=deepseek/deepseek-chat
    -> 移动端/Web: 原有 ai.ombhrum.com API
```

## 为什么要内置 runtime

OpenClaw 官方 Gateway 运行在单个本地端口上，默认 loopback 绑定，并通过同一端口承载 WebSocket、HTTP API、Control UI 与 OpenAI-compatible `/v1/chat/completions` 等接口。桌面 App 作为可信本机客户端可以持有 Gateway token，但 token 只保存在本机 SharedPreferences 中，不暴露到移动端。本机 OpenClaw 默认模型为 `deepseek/deepseek-chat`，由 App 启动 Gateway 时通过 `DEEPSEEK_API_KEY` 环境变量交给 OpenClaw 使用。

## WorkBuddy 式随包安装

参考 WorkBuddy 桌面包的做法，运行时不要求用户单独安装。WorkBuddy 把 CLI 与 Node runtime 放进 `.app/Contents/Resources`，随 DMG 一起交付；用户只看到正常安装 App。大乘桌面版采用同一个产品原则：CI/打包机在 release 构建时把 OpenClaw 与 Node runtime vendored 到 Flutter assets，最终它们位于 `.app/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/openclaw/...`。App 首次启动时只在应用内部从已签名的 bundle 资源释放到用户级 Application Support 目录，然后启动本机 Gateway。

会员和非会员在桌面端都走这条本机 OpenClaw 链路。会员身份只作为本机 OpenClaw 会话上下文传入，不作为切换云端 API 的条件。

## Release 打包步骤

在发布桌面包前，对目标平台运行：

```bash
cd fabushi
scripts/build_openclaw_desktop_bundle.sh macos-arm64
flutter build macos --release
```

Windows / Linux 对应：

```bash
scripts/build_openclaw_desktop_bundle.sh windows-x64
flutter build windows --release

scripts/build_openclaw_desktop_bundle.sh linux-x64
flutter build linux --release
```

最终 App 包中会包含：

```text
assets/openclaw/<platform>/node/...
assets/openclaw/<platform>/openclaw/...
assets/openclaw/bundle_manifest.json
```

用户首次打开桌面版时，App 会把这些只读 assets 释放到用户级 Application Support 目录，然后从那里启动 Gateway。用户不需要安装 Node、npm 或 openclaw。

## 设置入口

个人中心右上角已有“设置”。补丁在设置页加入“桌面 AI / OpenClaw”卡片：

- 自动：桌面端走内置 OpenClaw，移动端走 API；
- 本机 OpenClaw：强制走本机 Gateway；
- 云端 API：排障/灰度时可回退到原有 API；
- 检测：检查本机 runtime / Gateway 状态；
- 重启本机 AI：停止并重新启动内置 Gateway。

## 注意

补丁包里包含 runtime 目录结构和构建脚本，但不直接塞入第三方 Node/OpenClaw 二进制。实际桌面 release 需要在 CI 或打包机运行 `scripts/build_openclaw_desktop_bundle.sh` 把 runtime 放入 assets 后再构建 App。这样用户侧仍然是“内置且开箱即用”，不会发生用户本地安装。
