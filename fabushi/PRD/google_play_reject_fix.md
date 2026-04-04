# 修复 Google Play Console 驳回问题需求文档 (PRD)

## 1. 需求背景
应用在提交 Google Play Console 审核时遭遇了驳回，主要违反了两项政策：
- **Misleading Claims（误导性声明）**：Google 商店提审名称为“大乘”，但在应用安装后的元数据/应用名称中，系统检测到了不一致（`AndroidManifest.xml` 中将 label 写为了 `global_dharma_sharing`）。
- **Broken Functionality（功能受损）**：应用在某些测试设备上（或审核自动化脚本测试时）在启动时立即崩溃。捕获到的 Flutter 异常为 `PlatformException(channel-error, Unable to establish connection on channel., null, null)`，意味着 Dart 层调用的某个 `MethodChannel` 在 Android 原生层并未注册或已失效。

## 2. 根本原因剖析 (First Principles Thinking)
### 误导性声明
- `android/app/src/main/AndroidManifest.xml` 中 `<application>` 的 `android:label` 属性硬编码为 `global_dharma_sharing`。这必须与 Google Play 上的应用详情展示名称保持一致，即 “大乘”。

### 功能受损 (PlatformException channel-error)
- 在前一阶段的版本重构中，保活服务从 `flutter_foreground_task` 迁移至了更加稳定的 `audio_service`。
- 在 `pubspec.yaml` 中，`flutter_foreground_task` 依赖已被移除。
- **但遗留问题在于：**
  - 在 `AndroidManifest.xml` 中仍然保留声明了 `com.pravera.flutter_foreground_task.service.ForegroundService`，它并不存在于编译后的 DEX 原生字节码中。
  - 更重要的是，这会导致本地构建缓存（`GeneratedPluginRegistrant.java` 等文件）未能完全清理和同步。如果此前没有执行彻底的清理重建，应用内部可能仍留有无效通道的残渣映射。当引擎尝试派发或响应某些未清理的隔离任务时便会抛出 `channel-error`。

## 3. 修复方案实施计划
1. **解决 Misleading Claims：**
   将 `AndroidManifest.xml` 中 `application` 的 `android:label` 明确指定为 `大乘`。
2. **解决 Broken Functionality：**
   - 彻底从 `<application>` 标签下移除无关的 `ForegroundService` 声明。
   - 必须通过 `flutter clean` 清除缓存垃圾。
   - 重新执行 `flutter pub get` 与 `flutter build appbundle`，确保 `GeneratedPluginRegistrant` 及 Flutter Engine 对原生通道插件的映射全剧本正确生成。

## 4. 完成标准
- `.aab` 文件的反编译 `AndroidManifest.xml` 中应用展示名称和服务保持绝对纯净且匹配。
- 用户无须再单独排查代码问题，直接得到重新构建好、修复所有已知隐患的新包文件即可再次登入 Google Play Console 提审。
