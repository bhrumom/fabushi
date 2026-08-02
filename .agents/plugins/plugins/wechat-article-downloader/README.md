# 微信公众号归档器

Rust CLI/MCP 插件，从任意公开的 `https://mp.weixin.qq.com/s/...` 文章链接出发，归档同一公众号**公开可访问**的文章。

## 发现路径

1. 解析种子文章中的公众号 `biz`、文章 `mid/idx`、专辑 ID、前后文章链接。
2. 使用微信公开专辑分页接口递归展开专辑。
3. 使用搜狗微信公开索引补充未被种子专辑覆盖的公开文章。
4. 每篇新文章继续发现其他专辑和同公众号文章，直到队列收敛。

插件不会破解验证码、伪造登录态或绕过平台风控。若公开索引要求验证码，该来源会停止；若用户合法持有自己的微信会话 Cookie，可通过 `cookie`、`cookieFile` 或 `WECHAT_COOKIE` 提供，用于访问本人已获授权的内容。

## CLI

```sh
fabushi-plugin-cli --plugin wechat-article-downloader inspect --json '{"url":"https://mp.weixin.qq.com/s/..."}'

fabushi-plugin-cli --plugin wechat-article-downloader download --json '{
  "url":"https://mp.weixin.qq.com/s/...",
  "outputDir":"wechat-archive",
  "downloadImages":false,
  "searchPages":10
}'
```

输出目录包含：

- `manifest.json`：公众号、文章、专辑、失败项和发现来源。
- `index.html`：离线文章目录。
- `articles/<mid>-<idx>-<title>/index.html`：清理后的文章正文。
- `articles/.../metadata.json`：文章元数据。
- `articles/.../images/`：启用 `downloadImages` 时的本地图片。

`maxArticles: 0` 表示不设置文章数量上限。`strict: true` 会在存在失败项时让命令返回失败。
