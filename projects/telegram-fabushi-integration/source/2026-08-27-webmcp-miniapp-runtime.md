# 2026-08-27 — 全量 WebMCP MiniApp 架构升级

## 用户要求

所有 Fabushi MiniApp 必须内置 WebMCP；当前打开的小程序由 Mahayana 直接发现并调用其 Tool。全球法布施等需要后台运行的能力继续由 Rust/Native Runtime 承担，WebMCP 作为前台 Agent 控制面，不得把长任务生命周期绑定到网页。

## 目标架构

```text
Mahayana Agent
  ├─ 当前 MiniApp 打开 -> WebMCP -> same Tool contract -> Rust/Native/Remote executor
  └─ 页面关闭/后台任务 -> Mahayana Host Tool -> same Tool contract -> Rust/Native executor

MiniApp UI button -> same Tool contract -> same executor
Slash command      -> Tool metadata projection
```

## 强制要求

- 每个 MiniApp 页面必须暴露 WebMCP Tool。
- Tool 名称、schema、annotations 以真实 Tool catalog 为唯一事实源，不维护第二份 WebMCP 映射。
- 写入、破坏性、open-world Tool 保留现有确认与权限策略。
- WebMCP 不替代 Rust 后台 Job、队列、数据库、系统能力、恢复能力。
- 页面销毁时 WebMCP Tool 必须注销；已启动 Rust Job 不得因此停止。
- 浏览器/WebView 未原生实现 WebMCP 时，Fabushi Host 提供兼容 registry/bridge；一旦原生可用优先标准接口。
- 移动 App 主壳继续保持 SwiftUI/Compose；仅 MiniApp surface 可使用受控 WebView/WKWebView，禁止退回 WebView 主应用壳。
- 新 MiniApp 发布/生成流程必须包含 WebMCP 验收。

## 发布要求

通过 PR 合并到 canonical `main`，执行 exact-main packaged desktop/mobile E2E，随后发布严格递增的新版本 GitHub Release。
