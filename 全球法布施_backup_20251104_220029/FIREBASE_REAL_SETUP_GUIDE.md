# Firebase 真实配置完整指南

## 📋 前置准备

- Google 账号
- 项目包名：`com.ombhrum.fabushi`
- 10-15分钟时间

---

## 🔥 步骤1：创建 Firebase 项目

### 1.1 访问 Firebase Console
```
https://console.firebase.google.com
```

### 1.2 创建新项目
1. 点击 **"添加项目"**
2. 项目名称：`全球法布施` 或 `Global Dharma`
3. 项目ID：自动生成（记住这个ID）
4. Google Analytics：**可选**（建议关闭，简化配置）
5. 点击 **"创建项目"**

---

## 📱 步骤2：添加应用

### 2.1 添加 macOS 应用

1. 在项目概览页，点击 **iOS 图标**（macOS使用iOS配置）
2. 填写信息：
   ```
   Apple 捆绑包 ID: com.ombhrum.fabushi
   应用昵称: 全球法布施 macOS
   App Store ID: (留空)
   ```
3. 点击 **"注册应用"**

### 2.2 下载配置文件

1. 下载 `GoogleService-Info.plist`
2. **重要**：替换现有文件
   ```bash
   # 在项目根目录执行
   cp ~/Downloads/GoogleService-Info.plist macos/Runner/
   ```

### 2.3 添加 Android 应用（可选）

1. 点击 **Android 图标**
2. 填写信息：
   ```
   Android 软件包名称: com.ombhrum.fabushi
   应用昵称: 全球法布施 Android
   ```
3. 下载 `google-services.json`
4. 放置到：
   ```bash
   cp ~/Downloads/google-services.json android/app/
   ```

### 2.4 添加 Web 应用（可选）

1. 点击 **Web 图标** `</>`
2. 应用昵称：`全球法布施 Web`
3. 不勾选 Firebase Hosting
4. 点击 **"注册应用"**
5. **复制配置代码**（下一步会用到）

---

## 🔧 步骤3：更新代码配置

### 3.1 更新 `lib/firebase_options.dart`

用 Firebase Console 提供的配置替换：

```dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError('DefaultFirebaseOptions未配置此平台');
    }
  }

  // 从 Firebase Console Web 配置复制
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',              // 替换这里
    appId: 'YOUR_WEB_APP_ID',                // 替换这里
    messagingSenderId: 'YOUR_SENDER_ID',     // 替换这里
    projectId: 'YOUR_PROJECT_ID',            // 替换这里
    authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  // 从 google-services.json 复制
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',          // 替换这里
    appId: 'YOUR_ANDROID_APP_ID',            // 替换这里
    messagingSenderId: 'YOUR_SENDER_ID',     // 替换这里
    projectId: 'YOUR_PROJECT_ID',            // 替换这里
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  // 从 GoogleService-Info.plist 复制
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',              // 替换这里
    appId: 'YOUR_IOS_APP_ID',                // 替换这里
    messagingSenderId: 'YOUR_SENDER_ID',     // 替换这里
    projectId: 'YOUR_PROJECT_ID',            // 替换这里
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.ombhrum.fabushi',
  );

  // macOS 使用相同的 iOS 配置
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',              // 与iOS相同
    appId: 'YOUR_IOS_APP_ID',                // 与iOS相同
    messagingSenderId: 'YOUR_SENDER_ID',     // 与iOS相同
    projectId: 'YOUR_PROJECT_ID',            // 与iOS相同
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.ombhrum.fabushi',
  );
}
```

### 3.2 如何找到配置值

#### 从 `GoogleService-Info.plist` 获取（macOS/iOS）：
```xml
<key>API_KEY</key>
<string>AIzaSy...</string>  <!-- 这是 apiKey -->

<key>GOOGLE_APP_ID</key>
<string>1:123...:ios:abc...</string>  <!-- 这是 appId -->

<key>GCM_SENDER_ID</key>
<string>123456789012</string>  <!-- 这是 messagingSenderId -->

<key>PROJECT_ID</key>
<string>your-project-id</string>  <!-- 这是 projectId -->
```

#### 从 Firebase Console Web 配置获取：
```javascript
const firebaseConfig = {
  apiKey: "AIzaSy...",           // 复制这个
  authDomain: "xxx.firebaseapp.com",
  projectId: "your-project-id",  // 复制这个
  storageBucket: "xxx.appspot.com",
  messagingSenderId: "123456789012",  // 复制这个
  appId: "1:123...:web:abc..."   // 复制这个
};
```

---

## 🔐 步骤4：启用 Authentication

### 4.1 启用邮箱/密码登录

1. 在 Firebase Console，点击左侧 **"Authentication"**
2. 点击 **"开始使用"**
3. 选择 **"登录方法"** 标签
4. 点击 **"电子邮件地址/密码"**
5. 启用 **"电子邮件地址/密码"**
6. 点击 **"保存"**

### 4.2 启用 Google 登录

1. 在 **"登录方法"** 中，点击 **"Google"**
2. 启用开关
3. 项目支持电子邮件：选择你的邮箱
4. 点击 **"保存"**

### 4.3 配置授权域名（Web）

1. 在 **"设置"** 标签
2. 找到 **"授权域"**
3. 添加你的域名（如果部署到Web）：
   ```
   localhost
   your-domain.com
   ```

---

## ✅ 步骤5：测试配置

### 5.1 运行应用

```bash
# 清理缓存
flutter clean
flutter pub get

# 运行 macOS
flutter run -d macos

# 或运行 Web
flutter run -d chrome
```

### 5.2 测试登录

1. 点击 **"登录"** 按钮
2. 点击 **"Firebase 登录"**
3. 尝试注册新用户
4. 检查 Firebase Console > Authentication > Users

### 5.3 验证成功标志

控制台应显示：
```
✅ Firebase初始化成功
```

Firebase Console 应显示新用户。

---

## 🔍 常见问题

### Q1: "Firebase has not been correctly initialized"

**解决方案**：
- 确认 `GoogleService-Info.plist` 在正确位置
- 确认 `firebase_options.dart` 配置正确
- 重新运行 `flutter clean && flutter pub get`

### Q2: Google 登录失败

**解决方案**：
1. 确认已启用 Google 登录方法
2. macOS 需要配置 URL Schemes：
   ```xml
   <!-- 在 macos/Runner/Info.plist 添加 -->
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   ```

### Q3: 邮箱验证邮件未收到

**解决方案**：
- 检查垃圾邮件文件夹
- 在 Firebase Console > Authentication > Templates 自定义邮件模板

---

## 📊 步骤6：监控和管理

### 6.1 查看用户

Firebase Console > Authentication > Users

### 6.2 查看日志

Firebase Console > Analytics > Events（如果启用）

### 6.3 设置安全规则

Firebase Console > Firestore Database > Rules（如果使用数据库）

---

## 🎯 快速配置脚本

创建 `setup_firebase.sh`：

```bash
#!/bin/bash

echo "🔥 Firebase 配置助手"
echo ""
echo "请确保已完成以下步骤："
echo "1. 在 Firebase Console 创建项目"
echo "2. 下载配置文件到 ~/Downloads/"
echo ""

read -p "按 Enter 继续..."

# 复制 macOS 配置
if [ -f ~/Downloads/GoogleService-Info.plist ]; then
    cp ~/Downloads/GoogleService-Info.plist macos/Runner/
    echo "✅ macOS 配置已复制"
else
    echo "❌ 未找到 GoogleService-Info.plist"
fi

# 复制 Android 配置
if [ -f ~/Downloads/google-services.json ]; then
    cp ~/Downloads/google-services.json android/app/
    echo "✅ Android 配置已复制"
else
    echo "⚠️  未找到 google-services.json（可选）"
fi

echo ""
echo "📝 下一步："
echo "1. 更新 lib/firebase_options.dart"
echo "2. 运行: flutter clean && flutter pub get"
echo "3. 运行: flutter run"
```

使用：
```bash
chmod +x setup_firebase.sh
./setup_firebase.sh
```

---

## 🎉 完成！

配置完成后，你的应用将支持：
- ✅ 邮箱密码注册/登录
- ✅ Google 账号登录
- ✅ 邮箱验证
- ✅ 密码重置
- ✅ 用户管理

需要帮助？查看：
- Firebase 文档：https://firebase.google.com/docs/flutter/setup
- FlutterFire 文档：https://firebase.flutter.dev/
