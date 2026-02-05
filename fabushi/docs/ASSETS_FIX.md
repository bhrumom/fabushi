# 资源加载问题修复

## 问题诊断

从错误日志可以看到：
1. ❌ 佛像模型无法加载：`assets/models/佛像模型.glb`
2. ❌ 地球纹理无法加载：`assets/earth_texture.jpg`
3. ❌ 国家坐标数据无法加载：`assets/data/concap.csv`

## 原因

`flutter clean` 清理了构建缓存，需要完全重新构建应用。

## 解决方案

### 方法 1：完全重新构建（推荐）

```bash
# 1. 停止当前运行的应用
# 按 Ctrl+C 或在 IDE 中停止

# 2. 完全清理
flutter clean

# 3. 重新获取依赖
flutter pub get

# 4. 重新运行（不要用 hot reload）
flutter run
```

### 方法 2：强制重新构建

```bash
flutter run --no-hot
```

### 方法 3：针对特定平台

**macOS:**
```bash
flutter clean
flutter pub get
flutter run -d macos
```

**iOS:**
```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter run -d ios
```

**Android:**
```bash
flutter clean
flutter pub get
flutter run -d android
```

## 验证资源文件

确认资源文件存在：

```bash
ls -lh assets/models/佛像模型.glb
ls -lh assets/earth_texture.jpg
ls -lh assets/data/concap.csv
```

应该看到：
- ✅ 佛像模型.glb (约 158MB)
- ✅ earth_texture.jpg (约 2.4MB)
- ✅ concap.csv (约 14KB)

## 重要提示

⚠️ **不要使用 Hot Reload/Hot Restart**

资源文件更改后，必须完全重启应用：
- ❌ 不要用 `r` (hot reload)
- ❌ 不要用 `R` (hot restart)
- ✅ 停止应用，重新运行 `flutter run`

## 预期结果

重新构建后应该看到：
- ✅ 首页显示 3D 地球
- ✅ 禅室显示 3D 佛像模型
- ✅ 视频页面显示"暂无视频"提示（需要添加 Firestore 数据）

## 如果问题仍然存在

### 检查 pubspec.yaml

确认资源配置正确：

```yaml
flutter:
  assets:
    - assets/images/
    - assets/data/
    - assets/built_in/
    - assets/models/
    - assets/earth_texture.jpg
```

### 检查文件权限

```bash
chmod -R 755 assets/
```

### 重新生成代码

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 视频流功能

视频页面显示"暂无视频"是正常的，需要在 Firebase Firestore 添加数据。

参考 `VIDEO_FEED_READY.md` 添加测试视频数据。

---

**总结：执行 `flutter clean && flutter pub get && flutter run` 即可解决问题！**
