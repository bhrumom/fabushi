# 04 Electron 与 UI 融合

当前 main 与历史 Grok 融合分支均存在 `desktop/electron`，且 main 的 `main.cjs`、`host-process.cjs`、`native-edge.cjs`、`preload.cjs` 已出现后续变化。迁移必须按文件和 IPC 行为比较，禁止用旧分支覆盖。

UI 保持一套 Fabushi renderer。Grok 可取交互模式以组件/状态机重实现；品牌、导航、联系人/Agent、工具状态必须与现有 Fabushi 信息架构统一。
