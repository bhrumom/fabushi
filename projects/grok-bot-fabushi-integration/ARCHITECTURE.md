# Target Architecture

## 目标

把 Grok Bot 可取能力吸收到 Fabushi 的单一产品架构，而不是嵌套一个 Grok Bot 应用。

## 分层

1. **Renderer/UI**：Fabushi Electron renderer 负责界面、状态展示、动画与用户交互。
2. **Preload contract**：只暴露版本化、最小权限、可验证的 IPC contract。
3. **Electron main**：窗口生命周期、系统集成、授权编排，不承担重复 Agent 业务内核。
4. **Host capability layer**：文件、进程、浏览器、设备、桌面控制等本机能力统一走 capability gate。
5. **Mahayana sovereign kernel**：Agent loop、tool dispatch、policy、session、context、MCP/extension 等统一运行时。
6. **Platform adapters**：macOS/Windows/Linux/iOS/Android 差异通过适配器隔离。

## 禁止

- renderer 直接执行任意 shell。
- preload 暴露通用 `ipcRenderer`。
- Grok 来源代码形成第二套长期 supervisor/coordinator。
- 整分支回灌导致 Flutter/Tauri 或其它退役架构复活。
