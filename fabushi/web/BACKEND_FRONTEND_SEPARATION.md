# Cloudflare 后端与前端分离说明

当前 `web/wrangler.toml` 已调整为纯 Cloudflare Worker 后端配置，部署后端不再读取或上传 Flutter Web 的 `build/web`。

## 后端部署

在 `web` 目录执行：

```bash
npx wrangler deploy --env production
```

验证：

```bash
curl https://api.ombhrum.com/health
```

## 前端配置

Flutter 前端通过 `AppConfig.currentBackendUrl` 调用后端，生产默认后端为：

```text
https://api.ombhrum.com
```

如果需要临时指向其他后端，可在构建前端时传入：

```bash
flutter build web --release --dart-define=API_BASE_URL=https://api.ombhrum.com
```

## 域名职责

- `api.ombhrum.com`: Cloudflare Worker API、R2 代理、WebSocket 在线人数。
- `flutter.ombhrum.com`: Flutter Web 静态站点、隐私政策和支持页面。

后端 Worker 不再托管 `/index.html`、`/main.dart.js`、`/privacy`、`/support` 等前端页面；未命中的非 API 路径会返回 JSON 404。
