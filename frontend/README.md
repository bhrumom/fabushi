# Fabushi Frontend Monorepo

这个目录承接两个新前端入口：

- `apps/web`：官网，使用 Next.js
- `apps/mp-wechat`：微信小程序，使用 Taro

共享层拆成两个包：

- `packages/shared`：品牌文案、导航、部分纯业务工具
- `packages/api-client`：统一 API 地址、请求封装、共享类型

## 为什么这样拆

1. 现有 `fabushi/` 目录继续保持 Flutter 主应用节奏，不被官网和小程序开发打断。
2. 官网和小程序共享接口层与领域模型，但不强行共享整套 UI。
3. 后续如果要扩 H5 活动页、落地页、公众号内页面，可以继续挂在这个 monorepo 里扩展。

## 快速开始

```bash
pnpm install
pnpm dev:web
pnpm dev:mp
```

## 约定

- 后端继续复用 `https://flutter.ombhrum.com`
- 新增接口或类型时，优先改 `packages/api-client`
- 新增品牌文案、导航、固定配置时，优先改 `packages/shared`
