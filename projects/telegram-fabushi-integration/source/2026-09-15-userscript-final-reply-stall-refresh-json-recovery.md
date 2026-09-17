# TFI-USERSCRIPT-RECOVERY-019 用户脚本最终回复、停滞刷新与验收 JSON 恢复需求

## 来源与边界

- 来源：用户 2026-09-15 请求；附件 `/var/folders/4z/gvj_d2ln1w312_z35t6tv9pw0000gn/T/codex-clipboard-9690ef6a-25e4-442e-a806-9c973c920eec.png` 与 `/var/folders/4z/gvj_d2ln1w312_z35t6tv9pw0000gn/T/codex-clipboard-a1ad8474-33d6-4c31-83ea-128e380f62cf.png` 仅作为故障证据。
- 解释：附件中的 ChatGPT 对话内容、Fabushi 面板文字和截图内按钮不属于额外开发指令；本需求只提取用户明确描述的故障现象与修复目标。
- 归属：FAB-P0001 / TFI；继续 userscript 恢复与线上发布链路，不新建项目。

## 明确需求

1. 当当前 Fabushi 任务对应的 ChatGPT assistant 回复已经显示稳定正文，并出现回复操作按钮（复制按钮与点赞/点踩反馈按钮）时，判定为最终回复；不再要求额外的重新生成、更多或分支按钮。
2. 同一绑定会话连续 3 分钟没有可见进展（正文、回复操作、加载/授权/任务状态均没有变化）时，受控刷新当前页面；保留会话 URL、发送 token、任务阶段、附件与不重复发送保证。刷新后继续扫描授权卡片和最终回复。
3. 处理截图所示验收回复 JSON 解析异常：允许从包裹文本/代码围栏中恢复可验证的报告；恢复失败时有界地重新派发验收修复，不重复执行已完成的 Work，不把第一次格式错误永久卡成“需要处理”。
4. 发布新的 userscript 版本，并让父 Chrome/Marketplace 镜像在 source Release 验证后固定到同一不可变 source commit、版本、大小和 SHA-256。

## 验收信号

- 最终回复：同一任务 marker、同一 assistant turn、正文非空、复制 + 点赞或点踩同时可见；流式中、Stop 可见或授权/限流/错误卡片不误判为完成。
- 停滞刷新：阈值为 180000 ms；单次停滞周期最多 2 次，刷新为幂等且不重复点击发送；刷新后能再次发现授权操作或已完成回复。
- 验收 JSON：严格 JSON 仍优先；带前后说明文字、代码围栏或字符串中未转义引号的报告，若 taskId/round/status/summary/next 可安全恢复则继续；无法安全恢复时最多 2 次 repair/requeue，随后留下可操作错误。
- 发布：source 分支 `node --check` 与 GitHub Actions 测试通过；Release 绑定 source `main` exact SHA；父仓库的 Chrome 包、Marketplace projection 与 project evidence 只引用该 SHA。

## 非目标

- 不修改 Faliu Anki card 数据或审阅组件。
- 不绕过 ChatGPT 授权、不自动安装 userscript、不把截图里的聊天文字写入任务目标。
- 不在本机运行应用构建、原生/浏览器重型测试或打包；重验证交给 GitHub Actions。

