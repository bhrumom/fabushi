# 灵光微信小程序

该目录是微信小程序外壳，复用 Flutter Web 发布后的页面。

## 配置

1. 在微信公众平台创建小程序。
2. 将 `miniprogram/pages/web/index.js` 中的 `WEB_URL` 改成已备案且配置到小程序业务域名的 Flutter Web 地址。
3. 上传前配置 GitHub Secrets：
   - `WECHAT_MINIPROGRAM_APPID`
   - `WECHAT_MINIPROGRAM_PRIVATE_KEY`

## 本地校验

```bash
cd miniprogram
npm install
npm run check
```
