# ChatGPT DMG Bot 会话体验需求（2026-09-09）

## 用户最新明确要求

用户纠正了此前的方向：本轮不是恢复历史 Flutter 客户端，也不是把 Flutter 作为当前目标。输入是本机 ChatGPT 安装包 ChatGPT.dmg；目标是从安装包观察 Electron/Chromium 客户端的 Bot 单会话交互规律，并将等价行为融合进 Fabushi 当前的 Electron + 原生 iOS/Android + Mahayana 架构。

历史 Flutter 文件不在本轮范围内，不能恢复、复制、迁移或作为设计基线。

## DMG 观察结论

安装包是 Electron/Chromium 桌面客户端，渲染层以会话页、composer、增量消息和运行状态组件组成。可以作为 clean-room 行为参考的模式包括：

- 每个 Bot 绑定稳定的会话身份；切换 Bot 只切换会话投影，不能清空另一个 Bot 的 transcript。
- 用户消息乐观显示；assistant 消息按增量事件更新，结束时转为稳定消息。
- thinking、model route、tool/action、approval、error 和最终回答属于独立时间线条目。
- 运行期间可停止；输入草稿按会话保存；忙碌时的新输入可以排队。
- assistant 长内容以文档流展示，支持 Markdown、代码块、链接和代码复制。
- 消息动作按需浮现，至少覆盖 copy、edit/resubmit、regenerate。
- 用户向上阅读时保留位置；有新内容时不强行抢焦点，并提供回到最新位置的入口。

安装包中的私有源码、私有资源、品牌资产和二进制不进入 Fabushi。没有把 app.asar 解包产物复制到仓库。

## 开源参考调查

调查在实现前完成，参考的是公开仓库的架构和许可证，不复制代码：

1. assistant-ui/assistant-ui：MIT。提供 Thread、Message、Composer、ActionBar、ThreadList 等可组合边界，并明确覆盖 streaming、auto-scroll、retry、attachment、markdown、code highlighting、accessibility。结论：采用其组件边界和状态分离思路；不新增依赖，因为 Fabushi 已有 React/CSS Modules、Mahayana Host 和原生适配器。
2. vercel/ai：Apache-2.0。UI message stream 将 text-delta、tool lifecycle、error 和 transport 分开，且 transport 参数支持新消息与重新生成。结论：采用“消息 parts/运行事件分离”和 abort/transport 语义；不引入第二个 provider/runtime，继续由 Mahayana Host 负责。
3. danny-avila/LibreChat：MIT。README 展示了 interrupt、durable queue、partial work、phase cards、branch/regenerate 和 resumable streams。结论：采纳排队、中断、部分输出保留和分支操作的行为目标；不复制其实现。
4. open-webui/open-webui：当前版本存在额外品牌限制条款，历史版本许可也不同。结论：不采用其代码或资源，只保留“会话持久化与流式可靠性应独立于渲染层”的观察。

公开参考：

- https://github.com/assistant-ui/assistant-ui
- https://github.com/assistant-ui/assistant-ui/blob/main/LICENSE
- https://github.com/vercel/ai
- https://github.com/vercel/ai/blob/main/LICENSE
- https://github.com/danny-avila/LibreChat
- https://github.com/danny-avila/LibreChat/blob/main/LICENSE
- https://github.com/open-webui/open-webui/blob/main/LICENSE

## Fabushi 实施边界

- Desktop：在现有统一 Messenger 中为 Bot 使用独立 transcript view；继续使用 Electron transport、Mahayana runtime 和既有鉴权/权限边界。
- Android：在 MobileBotViewModel 中按 Bot 保存 transcript/draft；继续使用原生 Compose 和 feature event pump。
- iOS：在 GrokMobileShell 中按 Bot 保存 transcript/draft；继续使用原生 SwiftUI 和 MahayanaHost。
- 共享事件：chat.message、chat.delta、agent.step、model.routed、operation.* 仍是事实来源；UI 不自行推断工具执行结果。
- 验收：本任务只能在实现完成后进入 CI、受保护 main、三端 packaged/simulated-user E2E、视觉证据和 Release 门禁；本地检查不能代替这些门禁。
