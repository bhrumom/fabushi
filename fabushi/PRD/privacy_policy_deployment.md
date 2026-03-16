# Privacy Policy Deployment

## Goal Description
为全球法布施项目构建并部署隐私政策网页，使其可通过 `https://flutter.ombhrum.com/privacy` 访问。以满足 App Store 审核关于 UGC 规范的需求。

## User Review Required
> [!WARNING]
> 为了部署 Cloudflare Worker，由于 Worker 的静态资源绑定（ASSETS）依赖于完整的 `build/web` 目录，而当前本地 `build/web` 目录不存在。如果直接部署会导致线上存在的应用文件被清空（404）。
> **必选操作**：我们需要先完整运行 `./build_optimized_web.sh` 编译所有的 Flutter Web 产物，然后再执行 `wrangler deploy` 进行部署。整个编译加部署大概需要数分钟。请确认是否执行完整编译与部署。

## Proposed Changes
### web/worker-modular.js （Cloudflare Worker）
增加针对 `/privacy` 的路由映射代理，直接返回 `privacy.html` 并设置正确的 Header 请求头，使其无需加 `.html` 后缀即可访问。

#### [MODIFY] worker-modular.js(file:///Users/gloriachan/Documents/fabushi/fabushi/web/worker-modular.js)
```javascript
      // /privacy 隐私政策页面路由
      if (url.pathname === '/privacy' || url.pathname === '/privacy/') {
        try {
          if (env.ASSETS) {
            const privacyRequest = new Request(new URL('/privacy.html', request.url), request);
            const assetResponse = await env.ASSETS.fetch(privacyRequest);
            if (assetResponse.status === 200) {
              const newResponse = new Response(assetResponse.body, {
                status: 200,
                headers: {
                  'Content-Type': 'text/html; charset=utf-8',
                  'Access-Control-Allow-Origin': '*',
                  'Cache-Control': 'public, max-age=3600',
                },
              });
              return newResponse;
            }
          }
        } catch (e) {
          console.error('Error serving privacy page from assets:', e);
        }
        return Response.redirect(new URL('/privacy.html', request.url).href, 307);
      }
```

## Verification Plan
### Automated Tests
1. [x] 编译完成后，将 `web/privacy.html` 复制到 `build/web/privacy.html` 中（以保万全，由于 flutter build web 自动把 web 下内容复制，正常情况已存在）。
2. [x] 执行 `cd web && wrangler deploy --env production`。
3. [x] 部署后，请求 `curl -I https://flutter.ombhrum.com/privacy`，验证返回 200 状态码。

**验证结果：** 完全通过，已返回 HTTP/2 200，并且 `content-type: text/html`。隐私政策页面部署和映射成功完成。
