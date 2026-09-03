# 2026-08-26 — Desktop revoked-session + marketplace recovery

用户现场截图：Fabushi 1.0.941 在全局“应用”搜索“全球法布施”时无结果，顶部显示 `HTTP 401: refresh_token_reused: 登录会话已撤销，请重新登录`；用户同时无法在新的 Messenger UI 找到退出登录入口。随后明确要求：“请你完全修复并发布一个新的版本。”

验收含义：修复必须覆盖 session 生命周期、用户可见退出入口、公开 Marketplace 搜索的认证解耦、自动化测试、canonical main 合并、打包 E2E 与 updater-compatible GitHub Release；不能只清本机缓存或只修生产数据库。
