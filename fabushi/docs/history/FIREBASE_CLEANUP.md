# Firebase 旧应用清理指南

## ✅ 已完成
- Android 配置已更新为 `com.ombhrum.fabushi`
- iOS 配置已更新为 `com.ombhrum.fabushi`

## ⚠️ 需要手动删除的旧应用

Firebase CLI 不支持删除应用，需要在 Firebase Console 中手动删除：

### 1. 访问 Firebase Console
https://console.firebase.google.com/project/quanqiubushi/settings/general

### 2. 删除以下旧应用

#### Android 旧应用
- **包名**: `com.example.global_dharma_sharing`
- **App ID**: `1:700291601159:android:483ce3e0269ff91b622ba2`
- **操作**: 在应用列表中找到此应用 → 点击设置图标 → 删除应用

#### iOS 旧应用
- **Bundle ID**: `com.example.globalDharmaSharing`
- **App ID**: `1:700291601159:ios:ae57131c72d41361622ba2`
- **操作**: 在应用列表中找到此应用 → 点击设置图标 → 删除应用

### 3. 保留的应用（新包名）

✅ **Android**: `com.ombhrum.fabushi` (App ID: 1:700291601159:android:6266ae078c4aa918622ba2)
✅ **iOS**: `com.ombhrum.fabushi` (App ID: 1:700291601159:ios:a37861f095a35c41622ba2)
✅ **Web**: (App ID: 1:700291601159:web:2749eebfa8b73ef9622ba2)

## 验证配置

运行以下命令验证当前配置：

```bash
# 查看 Android 包名
grep "package_name" android/app/google-services.json

# 查看 iOS Bundle ID
grep -A 1 "BUNDLE_ID" ios/Runner/GoogleService-Info.plist
```

应该只显示 `com.ombhrum.fabushi`
