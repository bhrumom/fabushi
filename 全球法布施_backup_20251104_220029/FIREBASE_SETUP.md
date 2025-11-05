# Firebase Authentication 集成指南

## 已完成的集成

### 1. 依赖添加
已在 `pubspec.yaml` 中添加：
- `firebase_core: ^3.8.1`
- `firebase_auth: ^5.3.3`
- `google_sign_in: ^6.2.2`

### 2. 服务封装
创建了 `lib/services/firebase_auth_service.dart`，提供：
- 邮箱密码注册/登录
- Google 登录
- 邮箱验证
- 密码重置
- 与现有后端同步

### 3. UI界面
创建了 `lib/screens/firebase_login_screen.dart`

## 配置步骤

### Android 配置

1. 在 Firebase Console 创建项目
2. 添加 Android 应用，包名：`com.example.global_dharma_sharing`
3. 下载 `google-services.json` 到 `android/app/`
4. 修改 `android/build.gradle.kts`：
```kotlin
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}
```

5. 修改 `android/app/build.gradle.kts`：
```kotlin
plugins {
    id("com.google.gms.google-services")
}
```

### iOS 配置

1. 在 Firebase Console 添加 iOS 应用，Bundle ID：`com.example.globalDharmaSharing`
2. 下载 `GoogleService-Info.plist` 到 `ios/Runner/`
3. 在 Xcode 中添加该文件到项目

### Web 配置

1. 在 Firebase Console 添加 Web 应用
2. 创建 `lib/firebase_options.dart`：
```dart
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: "YOUR_API_KEY",
      authDomain: "YOUR_PROJECT.firebaseapp.com",
      projectId: "YOUR_PROJECT_ID",
      storageBucket: "YOUR_PROJECT.appspot.com",
      messagingSenderId: "YOUR_SENDER_ID",
      appId: "YOUR_APP_ID",
    );
  }
}
```

3. 更新 `main.dart` 初始化：
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

## 使用方法

### 基本登录
```dart
final firebaseAuth = FirebaseAuthService();

// 邮箱登录
final result = await firebaseAuth.signInWithEmail(email, password);

// Google 登录
final result = await firebaseAuth.signInWithGoogle();

// 登出
await firebaseAuth.signOut();
```

### 集成到现有登录流程
在 `lib/screens/login_screen.dart` 中添加：
```dart
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FirebaseLoginScreen(),
      ),
    );
  },
  child: const Text('使用 Firebase 登录'),
)
```

## 启用认证方式

在 Firebase Console > Authentication > Sign-in method 中启用：
- ✅ Email/Password
- ✅ Google

## 运行应用

```bash
# 安装依赖
flutter pub get

# 运行
flutter run
```

## 注意事项

1. Firebase 配置文件不要提交到 Git
2. 生产环境使用环境变量管理密钥
3. 启用邮箱验证提高安全性
4. 配置 OAuth 重定向 URL
