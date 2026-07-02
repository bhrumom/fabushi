# 全球法布施：本地优先、无默认云端兜底策略

## 结论

全球法布施小程序的运行策略改为：

```text
本地能运行的，都在本地运行。
不使用云端作为默认兜底。
当前设备本地无法运行时，明确提示升级 App、安装本地组件或切换到桌面端。
```

这份文档优先级高于早期文档中提到的云端兜底表达。后续实现以本地优先为准。

## 统一执行策略

```json
{
  "mode": "local-first",
  "cloudFallback": false,
  "onUnsupported": "showUpgradeOrSwitchDevice"
}
```

含义：

```text
1. 桌面端能跑本地 worker，就跑本地 worker。
2. 移动端能跑 JS/WASM/内置 Rust library，就在移动端本地跑。
3. Web 端能跑 JS/WASM，就在浏览器本地跑。
4. 不把长任务静默切到远程执行。
5. 当前设备不具备本地能力时，返回 unsupported_local_runtime。
```

## 平台策略

| 平台 | 本地执行策略 | 不支持时 |
|---|---|---|
| macOS | 本地 Rust worker、本地脚本运行时、本地任务组件 | 提示安装组件或升级宿主 |
| Windows | 本地 Rust worker、本地脚本运行时、本地任务组件 | 提示安装组件或升级宿主 |
| Linux | 本地 Rust worker、本地脚本运行时、本地任务组件 | 提示安装组件或升级宿主 |
| iOS | JS/WASM/内置 Rust library、本地任务状态 | 提示升级 App 或切换桌面端 |
| Android | JS/WASM/内置 Rust library、内置轻量解释器、受控前台任务 | 提示升级 App 或切换桌面端 |
| Web | 浏览器 JS/WASM、本地状态 | 提示切换 App 或桌面端 |

## 全球法布施启动行为

```text
打开全球法布施小程序
  -> 宿主读取 manifest
  -> 确认 source=official + reviewStatus=trusted
  -> 确认 executionPolicy.cloudFallback=false
  -> 查找当前设备本地可用 runtime
  -> 有可用 runtime：本地启动任务
  -> 无可用 runtime：返回 unsupported_local_runtime
  -> UI 展示日志、回执、状态、停止按钮
```

## 推荐 runtime 顺序

```text
桌面：rustProgramDesktop -> localToolDesktop -> wasm -> script.js -> script.lua -> script.pythonLite
移动：rustLibrary -> wasm -> script.js -> script.lua -> script.pythonLite
Web：wasm -> script.js
```

## Manifest 示例

```json
{
  "miniAppId": "official.global-dharma",
  "launch": {
    "mode": "auto",
    "entrypoint": "onLaunch",
    "resumePreviousJob": true,
    "showRunningIndicator": true
  },
  "executionPolicy": {
    "mode": "local-first",
    "cloudFallback": false,
    "onUnsupported": "showUpgradeOrSwitchDevice"
  },
  "runtime": {
    "preferred": "rustProgramDesktop",
    "fallback": [
      "rustLibrary",
      "wasm",
      "script.js",
      "script.lua",
      "script.pythonLite"
    ]
  }
}
```

## 移动端特殊说明

移动端不是不能自动运行，而是只能运行宿主允许的本地 runtime：

```text
JS onLaunch
WASM on_launch
内置 Rust library
宿主内置轻量解释器
系统允许的本地前台/后台任务
```

如果这些本地能力不足以支持持续循环发送，则产品上应提示：

```text
当前设备不支持本地持续运行，请升级 App 或切换到桌面端。
```

不要在用户无感知时切到远程执行。

## 用户感知

用户看到的是：

```text
打开全球法布施，它会在当前设备本地开始运行能运行的部分。
```

如果当前设备不支持本地长循环，用户看到的是明确提示，而不是静默远程执行。
