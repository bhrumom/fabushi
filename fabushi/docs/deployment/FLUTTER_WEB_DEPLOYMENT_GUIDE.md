# Flutter Web部署到Cloudflare指南

本指南将帮助你将Flutter Web应用部署到Cloudflare Pages，实现与后端Worker的完美集成。

## 📋 概述

Flutter Web应用将部署到Cloudflare Pages，与之前部署的Cloudflare Worker后端共享用户数据和会员系统。

## 🏗️ 部署架构

```
用户浏览器
    ↓
Cloudflare Pages (Flutter Web前端)
    ↓ API调用
Cloudflare Worker (后端API)
    ↓ 数据存储
Cloudflare KV + R2 (数据库和文件存储)
```

## 🚀 快速部署

### 方法一：使用自动部署脚本

```bash
# 给脚本执行权限
chmod +x deploy_web.sh

# 运行部署脚本
./deploy_web.sh
```

### 方法二：手动部署

#### 1. 准备环境

```bash
# 安装Flutter（如果未安装）
# 参考: https://flutter.dev/docs/get-started/install

# 安装Wrangler CLI
npm install -g wrangler

# 登录Cloudflare
wrangler login
```

#### 2. 配置Flutter Web

```bash
# 启用Flutter Web支持
flutter config --enable-web

# 检查Web支持是否启用
flutter devices
```

#### 3. 更新API配置

编辑 `lib/config/api_config.dart`，确保API URL指向你的Worker：

```dart
class ApiConfig {
  // 生产环境使用Worker URL
  static const String baseUrl = 'https://fabushi-prod.你的账户名.workers.dev';
  
  // 如果有自定义域名
  // static const String baseUrl = 'https://api.ombhrum.com';
}
```

#### 4. 构建Flutter Web

```bash
# 清理之前的构建
flutter clean

# 获取依赖
flutter pub get

# 构建Web应用
flutter build web --release --web-renderer html
```

#### 5. 配置Cloudflare Pages

创建 `web/wrangler.toml`（已创建）：

```toml
name = "fabushi-flutter-web"
main = "index.html"
compatibility_date = "2024-06-05"

[assets]
binding = "ASSETS"
directory = "./build/web"

[vars]
FLUTTER_WEB = "true"
API_BASE_URL = "https://fabushi-prod.你的账户名.workers.dev"
```

#### 6. 部署到Cloudflare Pages

```bash
cd web
wrangler pages deploy ../build/web --project-name fabushi-flutter-web
```

## 🔧 高级配置

### 1. 自定义域名配置

#### 在Cloudflare Dashboard中配置

1. 登录Cloudflare Dashboard
2. 进入Pages项目设置
3. 添加自定义域名
4. 配置DNS记录

#### 更新wrangler.toml

```toml
[env.production]
name = "fabushi-flutter-web-prod"
routes = [
  { pattern = "ombhrum.com/*", custom_domain = true },
  { pattern = "www.ombhrum.com/*", custom_domain = true }
]
```

### 2. 环境变量配置

#### 开发环境

```toml
[env.development]
name = "fabushi-flutter-web-dev"

[env.development.vars]
FLUTTER_WEB = "true"
API_BASE_URL = "https://fabushi-dev.你的账户名.workers.dev"
```

#### 生产环境

```toml
[env.production]
name = "fabushi-flutter-web-prod"

[env.production.vars]
FLUTTER_WEB = "true"
API_BASE_URL = "https://api.ombhrum.com"
```

### 3. 缓存策略配置

`web/_headers` 文件配置了不同资源的缓存策略：

- **静态资源**: 长期缓存（1年）
- **HTML文件**: 不缓存，确保更新
- **Service Worker**: 不缓存，确保功能正常

### 4. 路由配置

`web/_redirects` 文件配置了单页应用路由：

- 所有路由重定向到 `index.html`
- API请求代理到后端Worker
- 静态资源直接服务

## 📱 Flutter Web优化

### 1. Web渲染器选择

```bash
# HTML渲染器（推荐，兼容性好）
flutter build web --web-renderer html

# CanvasKit渲染器（性能好，但文件大）
flutter build web --web-renderer canvaskit

# 自动选择
flutter build web --web-renderer auto
```

### 2. 代码分割和懒加载

在 `web/index.html` 中配置：

```html
<script>
  window.addEventListener('load', function(ev) {
    // 延迟加载Flutter应用
    _flutter.loader.loadEntrypoint({
      serviceWorker: {
        serviceWorkerVersion: serviceWorkerVersion,
      }
    }).then(function(engineInitializer) {
      return engineInitializer.initializeEngine();
    }).then(function(appRunner) {
      return appRunner.runApp();
    });
  });
</script>
```

### 3. PWA配置

更新 `web/manifest.json`：

```json
{
  "name": "全球法布施",
  "short_name": "法布施",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#0175C2",
  "theme_color": "#0175C2",
  "description": "全球法布施 - 传播佛法智慧",
  "orientation": "portrait-primary",
  "prefer_related_applications": false,
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

## 🔄 CI/CD自动部署

### 1. GitHub Actions配置

创建 `.github/workflows/deploy.yml`：

```yaml
name: Deploy Flutter Web to Cloudflare Pages

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
        
    - name: Install dependencies
      run: flutter pub get
      
    - name: Build web
      run: flutter build web --release --web-renderer html
      
    - name: Deploy to Cloudflare Pages
      uses: cloudflare/pages-action@v1
      with:
        apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
        accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
        projectName: fabushi-flutter-web
        directory: build/web
        gitHubToken: ${{ secrets.GITHUB_TOKEN }}
```

### 2. 设置GitHub Secrets

在GitHub仓库设置中添加：

- `CLOUDFLARE_API_TOKEN`: Cloudflare API令牌
- `CLOUDFLARE_ACCOUNT_ID`: Cloudflare账户ID

## 🧪 测试和调试

### 1. 本地测试

```bash
# 启动本地开发服务器
flutter run -d chrome

# 或者构建后本地预览
flutter build web --release
cd build/web
python -m http.server 8000
```

### 2. 生产环境测试

部署后测试以下功能：

- [ ] 页面加载速度
- [ ] 用户注册和登录
- [ ] API请求是否正常
- [ ] 路由跳转是否正确
- [ ] 移动端适配
- [ ] PWA功能

### 3. 性能优化

```bash
# 分析包大小
flutter build web --analyze-size

# 生成性能报告
flutter build web --profile
```

## 🔐 安全配置

### 1. Content Security Policy

在 `web/index.html` 中添加：

```html
<meta http-equiv="Content-Security-Policy" 
      content="default-src 'self'; 
               script-src 'self' 'unsafe-inline' 'unsafe-eval'; 
               style-src 'self' 'unsafe-inline'; 
               img-src 'self' data: https:; 
               connect-src 'self' https://fabushi-prod.你的账户名.workers.dev;">
```

### 2. HTTPS强制

在 `web/_headers` 中配置：

```
/*
  Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

## 📊 监控和分析

### 1. Cloudflare Analytics

在Cloudflare Dashboard中查看：

- 页面访问量
- 加载时间
- 错误率
- 地理分布

### 2. Web Vitals监控

在Flutter应用中集成性能监控：

```dart
import 'package:web/web.dart' as web;

void trackWebVitals() {
  // 监控Core Web Vitals
  web.window.addEventListener('load', (event) {
    // 记录页面加载时间
    final loadTime = web.window.performance.now();
    print('Page load time: ${loadTime}ms');
  });
}
```

## 🚀 部署后检查清单

- [ ] 应用能正常加载
- [ ] 所有路由都能正确访问
- [ ] API请求正常工作
- [ ] 用户认证功能正常
- [ ] 会员系统功能正常
- [ ] 移动端适配良好
- [ ] PWA功能正常
- [ ] 自定义域名配置正确（如果有）
- [ ] HTTPS证书正常
- [ ] 缓存策略生效

## 🔄 更新和维护

### 更新应用

```bash
# 更新代码后重新部署
flutter build web --release
cd web
wrangler pages deploy ../build/web --project-name fabushi-flutter-web
```

### 回滚版本

```bash
# 在Cloudflare Dashboard中可以快速回滚到之前的版本
```

## 📞 故障排除

### 常见问题

1. **页面空白**
   - 检查控制台错误
   - 确认API URL配置正确
   - 检查CORS设置

2. **API请求失败**
   - 确认Worker正常运行
   - 检查网络连接
   - 验证API端点

3. **路由不工作**
   - 检查 `_redirects` 文件配置
   - 确认Flutter Router配置

4. **资源加载失败**
   - 检查 `_headers` 文件配置
   - 确认资源路径正确

### 调试技巧

1. 使用浏览器开发者工具
2. 查看Cloudflare Pages日志
3. 检查Worker日志
4. 使用Flutter Web调试工具

---

现在你的Flutter Web应用已经成功部署到Cloudflare Pages，与Worker后端完美集成！用户可以在Web端和移动端之间无缝切换，享受一致的体验。