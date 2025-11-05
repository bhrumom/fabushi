# Firebase 配置 - FlutterFire CLI 方式（推荐）

## 🚀 最简单的配置方法

使用 FlutterFire CLI 自动配置所有平台，无需手动编辑文件。

---

## 📋 步骤1：安装 FlutterFire CLI

```bash
# 安装 Firebase CLI
npm install -g firebase-tools

# 安装 FlutterFire CLI
dart pub global activate flutterfire_cli
```

验证安装：
```bash
firebase --version
flutterfire --version
```

---

## 🔐 步骤2：登录 Firebase

```bash
firebase login
```

浏览器会打开，使用 Google 账号登录。

---

## 🔥 步骤3：配置 Firebase 项目

在项目根目录执行：

```bash
cd /Users/gloriachan/Documents/全球发送/全球法布施

# 自动配置（推荐）
flutterfire configure
```

### 配置过程：

1. **选择或创建项目**
   - 选择现有项目，或
   - 输入新项目名称：`全球法布施` 或 `global-dharma`

2. **选择平台**
   ```
   ✓ android
   ✓ ios
   ✓ macos
   ✓ web
   ```
   使用空格选择，回车确认

3. **确认 Bundle ID**
   - iOS/macOS: `com.ombhrum.fabushi`
   - Android: `com.ombhrum.fabushi`

4. **自动生成配置**
   CLI 会自动：
   - 创建 Firebase 项目（如果不存在）
   - 注册所有平台应用
   - 下载配置文件
   - 生成 `lib/firebase_options.dart`

---

## ✅ 步骤4：启用 Authentication

### 方式1：使用 Firebase Console（推荐）

```bash
# 打开 Firebase Console
firebase open
```

然后：
1. 点击 **Authentication**
2. 点击 **开始使用**
3. 启用 **电子邮件/密码**
4. 启用 **Google**

### 方式2：使用命令行

```bash
# 启用 Authentication
firebase init auth
```

---

## 🧪 步骤5：测试配置

```bash
# 清理并重新构建
flutter clean
flutter pub get

# 运行应用
flutter run -d macos
```

控制台应显示：
```
✅ Firebase初始化成功
```

---

## 🔄 更新配置

如果需要添加新平台或更新配置：

```bash
# 重新配置
flutterfire configure

# 或指定项目
flutterfire configure --project=your-project-id
```

---

## 📁 生成的文件

FlutterFire CLI 会自动创建/更新：

```
✓ lib/firebase_options.dart          # 自动生成
✓ android/app/google-services.json   # 自动下载
✓ ios/Runner/GoogleService-Info.plist # 自动下载
✓ macos/Runner/GoogleService-Info.plist # 自动下载
✓ web/index.html                      # 自动更新
```

---

## 🎯 完整命令流程

```bash
# 1. 安装工具
npm install -g firebase-tools
dart pub global activate flutterfire_cli

# 2. 登录
firebase login

# 3. 配置项目
cd /Users/gloriachan/Documents/全球发送/全球法布施
flutterfire configure

# 4. 清理并运行
flutter clean
flutter pub get
flutter run -d macos
```

---

## 🔍 常见问题

### Q1: flutterfire 命令未找到

**解决方案**：
```bash
# 添加到 PATH
export PATH="$PATH":"$HOME/.pub-cache/bin"

# 或添加到 ~/.zshrc 或 ~/.bash_profile
echo 'export PATH="$PATH":"$HOME/.pub-cache/bin"' >> ~/.zshrc
source ~/.zshrc
```

### Q2: 配置失败

**解决方案**：
```bash
# 重新登录
firebase logout
firebase login

# 清除缓存
rm -rf ~/.config/firebase
flutterfire configure
```

### Q3: Bundle ID 不匹配

**解决方案**：
```bash
# 使用指定的 Bundle ID
flutterfire configure \
  --ios-bundle-id=com.ombhrum.fabushi \
  --macos-bundle-id=com.ombhrum.fabushi \
  --android-package-name=com.ombhrum.fabushi
```

---

## 🆚 对比手动配置

| 特性 | FlutterFire CLI | 手动配置 |
|------|----------------|---------|
| 配置时间 | 2分钟 | 15分钟 |
| 错误率 | 低 | 高 |
| 多平台 | 自动 | 逐个配置 |
| 更新 | 一键 | 手动 |
| 推荐度 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

---

## 📚 相关资源

- FlutterFire CLI: https://firebase.flutter.dev/docs/cli
- Firebase CLI: https://firebase.google.com/docs/cli
- 视频教程: https://www.youtube.com/watch?v=sz4slPFwEvs

---

## 🎉 完成！

使用 FlutterFire CLI 后，你的应用已完全配置好 Firebase，支持：
- ✅ 所有平台（Android, iOS, macOS, Web）
- ✅ 自动生成配置文件
- ✅ 一键更新
- ✅ 零手动编辑

现在可以直接使用 Firebase Authentication 功能！
