# Official MCP and same-account Chrome control intake

Date: 2026-09-12. Project: FAB-P0011 / CWA. Task: CWA-007.

用户要求：为 Fabushi Chrome 插件加入我们的登录系统，作为官方插件；官方 Fabushi MCP 可以直连登录同一个账号的 Chrome 插件并操作浏览器。将 ChatGPT Computer Control Bridge 的所有功能融合到 Fabushi Chrome，以后通过 Fabushi 实现这些功能。

Screenshot is UI reference only, not an additional instruction. This request does not authorize deleting the separate official ChatGPT extension or unrelated user data.

CWA-R009: Chrome signs into the existing Fabushi account independently of Electron.
CWA-R010: Official MCP discovers and controls only browsers registered to its authenticated account; logout removes access and stale sessions cannot regain control.
CWA-R011: Preserve all nine Bridge commands, actions, events, CDP/OOPIF/download/tab lifecycle and existing userscripts through the official extension.
CWA-R012: Package and verify account A positive, account B denied, logout/reconnect and full Bridge compatibility with exact-SHA CI evidence before release.

Latest verified baseline: PR #2535 merged at a9d0b883c68dd45c14f9966ab79656bcf43c4d0e; prior task documentation saying open is stale. That PR's checks succeeded. Post-main release closure has not been verified in this round.
