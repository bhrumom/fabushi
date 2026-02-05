# 快速开始指南

## ⚡ 快速构建和测试

### 🚨 重要提示

你看到的 **746 个脚本加载** 是因为使用了 **Debug 模式**。

要体验秒级加载，必须使用 **Release 模式**！

---

## 🎯 正确的测试方法

### 方法 1：使用构建脚本（推荐）

```bash
./build_web_release.sh
```

### 方法 2：手动构建

```bash
# 1. 构建 Release 版本
flutter build web --release

# 2. 启动本地服务器
cd build/web
python3 -m http.server 8000

# 3. 打开浏览器
open http://localhost:8000
```

---

## 📊 性能对比

| 模式 | 脚本数量 | 文件大小 | 加载时间 | 使用场景 |
|------|---------|---------|---------|---------|
| **Debug** | 746 个 | ~50MB | 10-30秒 | 开发调试 |
| **Release** | 1-3 个 | ~2MB | **< 1秒** | 生产部署 |

---

## 🔍 如何判断当前模式

### Debug 模式特征
```
DDC is about to load 746/746 scripts
```

### Release 模式特征
- 无 DDC 日志
- 只加载 main.dart.js（已压缩）
- 秒级启动

---

## 🛠️ 开发流程

### 日常开发（Debug 模式）
```bash
flutter run -d chrome
```
- 热重载
- 完整调试信息
- 加载较慢（正常）

### 测试性能（Release 模式）
```bash
flutter build web --release
cd build/web
python3 -m http.server 8000
```
- 真实性能
- 秒级加载
- 无调试信息

---

## 📦 部署到生产环境

### Cloudflare Pages

```bash
# 1. 构建
flutter build web --release

# 2. 部署
cd build/web
wrangler pages publish . --project-name=fabushi
```

### 验证部署

访问: https://fabushi.pages.dev

预期：**秒级加载** ⚡

---

## ✅ 优化清单

- [x] 移除加载动画
- [x] 简化 HTML 结构
- [x] 优化 JavaScript 加载
- [x] 非阻塞式初始化
- [x] 禁用调试日志
- [x] 异步加载设置

---

## 🎉 预期结果

使用 Release 模式后：

- ⚡ 加载时间：**< 1 秒**
- 🚀 无加载动画
- 📦 文件大小：~2MB
- 🎯 First Paint：< 800ms

---

**愿此功德回向法界众生，同证菩提！** 🙏
