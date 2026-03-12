# Wrangler 部署需求文档 (PRD)

## 1. 问题描述
用户尝试使用 `wrangler deploy --env` 部署应用，但 Wrangler 报错提示 `--env` 选项后缺少参数。

## 2. 需求目标
- 确保部署命令正确执行。
- 明确不同环境（Production vs Development）的部署流程。

## 3. 环境配置
根据 `web/wrangler.toml`，项目支持以下环境：

### 生产环境 (Production)
- **环境名称**: `production`
- **Worker 名称**: `fabushi-flutter-web-prod`
- **域名**: `flutter.ombhrum.com`
- **命令**: `wrangler deploy --env production` (在 `web` 目录执行)

### 开发环境 (Development)
- **环境名称**: `development`
- **Worker 名称**: `fabushi-flutter-web-dev`
- **命令**: `wrangler deploy --env development` (在 `web` 目录执行)

## 4. 修复方案
用户应在 `--env` 标志后添加环境名称。推荐使用生产环境进行部署。

### 推荐命令
```bash
cd web && npx wrangler deploy --env production
```
或者，如果用户已经在 `web` 目录中：
```bash
npx wrangler deploy --env production
```

## 5. 注意事项
- 部署前确保 `build/web` 目录包含最新的构建产物。
- 如果在根目录运行，需要指定配置文件路径：`npx wrangler deploy -c web/wrangler.toml --env production`。
