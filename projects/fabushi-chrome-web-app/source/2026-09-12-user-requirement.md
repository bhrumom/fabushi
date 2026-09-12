# 用户需求原文记录（2026-09-12）

用户要求：把 ChatGPT Computer Control Bridge Chrome 插件完全融合进 Fabushi 插件，
以后通过 Fabushi 实现原 Bridge 的全部功能，融合后删除 ChatGPT Computer Control
Bridge。

实施解释：采用 CWA-006，创建并登记 FAB-P0011 / CWA，发布 Fabushi Chrome 0.5.0，
保留 Fabushi 0.4.1 的产品 UI、桌面桥接和自动化脚本，兼容 list_tabs、claim_tab、
cdp、cdp_auto_attach_frame、downloads、tab_action、create_tab、cleanup_tabs、detach
及标签页/CDP 事件；验证并迁移后通过 Chrome 扩展管理界面删除旧 Bridge 和官方
ChatGPT 扩展，不删除共享 Computer Use MCP/native 辅助运行时。
