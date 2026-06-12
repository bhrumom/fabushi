# Fabushi Frontend Monorepo

这个目录承接两个新前端入口：

- `apps/web`：官网和新的 Web App，使用 Next.js
- `apps/mp-wechat`：微信小程序，使用 Taro 和微信原生组件，不使用 `web-view`

共享层拆成两个包：

- `packages/shared`：品牌文案、导航、部分纯业务工具
- `packages/api-client`：统一 API 地址、请求封装、共享类型

## 为什么这样拆

1. 现有 `fabushi/` 目录继续保持 Flutter 主应用节奏，不被官网和小程序开发打断。
2. 小程序复用 Flutter App 的信息架构、设计 token、领域数据和 API 协议；Flutter Widget 本身不能直接在微信原生运行时执行。
3. 后续如果要扩 H5 活动页、落地页、公众号内页面，可以继续挂在这个 monorepo 里扩展。

## 快速开始

```bash
pnpm install
pnpm dev:web
pnpm dev:mp
```

## 约定

- 主业务后端继续复用 `https://flutter.ombhrum.com`
- 新 Web App 路径是 `/app`，大乘 AI Web 入口是 `/app/ai`
- 官方站 Worker 通过 `/api/dacheng-ai/*` 反代大乘 AI 后端；小程序默认也调用这个 HTTPS 入口
- 微信小程序不走 WebView，页面由 Taro 编译为原生小程序组件；需要在微信后台配置 HTTPS request 合法域名
- 新增接口或类型时，优先改 `packages/api-client`
- 新增品牌文案、导航、固定配置时，优先改 `packages/shared`
