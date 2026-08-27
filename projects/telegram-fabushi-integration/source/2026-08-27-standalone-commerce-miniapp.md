# 用户需求源记录 — 独立站作为可独立运行 MiniApp

日期：2026-08-27
项目：FAB-P0001 / TFI
关联里程碑：M8 Mini Apps / Marketplace / WebMCP

## 原始意图

独立站不是 Fabushi 内部专属页面。普通用户从浏览器、Google、广告或直接 URL 进入时，应当可以完全独立浏览、加购、结账和购买；用户不需要安装 Fabushi，也不需要 Fabushi 账号。

当同一个独立站被上架到 Fabushi 小程序市场后，它额外获得 Fabushi 的分发、Bot、WebMCP/MCP 和 AI 操作能力。AI 应通过结构化 Commerce Tools 操作同一套商品、购物车和订单后端，而不是依赖视觉点击网页按钮。

## 本轮新增要求

1. 将上述独立运行 + Fabushi 可增强的 MiniApp 模型落实到现有市场。
2. 实际创建一个独立跨境电商站点并准备上线。
3. 该站点必须建立在成熟开源电商仓库之上，而不是从零自研通用电商内核。
4. 独立站需上架到 Fabushi Mini App 市场。
5. 在 Fabushi 内，AI 能搜索商品、查看详情、管理购物车、准备结账，并在明确用户批准后提交已就绪订单。

## 验收解释

“上线”只有在公网 HTTPS 站点和 MCP/manifest 探针通过后才成立；若生产主机、DNS 或支付 Provider 凭证不可用，只能标记为部署阻塞，不能把仓库实现冒充为已上线。
