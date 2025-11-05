# 文本服务修复总结

## 问题描述
法流无法从后端 `flutter.ombhrum.com` 获取文本书籍内容。

## 问题原因

### 1. API路径错误
原代码使用的路径：`/assets/data/asset-manifest.json`  
正确路径应该是：`/asset-manifest.json`

### 2. 文本编码问题
后端存储的txt文件使用 **GBK编码**，而原代码尝试使用UTF-8解码，导致乱码。

## 修复方案

### 1. 修复API路径
**文件**: `lib/services/cloudflare_text_service.dart`

```dart
// 修改前
final response = await http.get(
  Uri.parse('$baseUrl/assets/data/asset-manifest.json'),
).timeout(const Duration(seconds: 5));

// 修改后
final response = await http.get(
  Uri.parse('$baseUrl/asset-manifest.json'),
).timeout(const Duration(seconds: 5));
```

### 2. 添加GBK编码支持
**文件**: `pubspec.yaml`

添加依赖（使用纯Dart实现，支持所有平台）：
```yaml
dependencies:
  gbk_codec: ^0.4.0
```

### 3. 实现GBK解码
**文件**: `lib/services/cloudflare_text_service.dart`

```dart
import 'package:gbk_codec/gbk_codec.dart';

// 在_getCloudTextContent方法中
if (contentResponse.statusCode == 200) {
  String content;
  try {
    // 先尝试UTF-8
    content = utf8.decode(contentResponse.bodyBytes);
  } catch (e) {
    // UTF-8失败，使用GBK解码
    try {
      content = gbk_bytes.decode(contentResponse.bodyBytes);
      print('Successfully decoded GBK content');
    } catch (e2) {
      print('GBK decoding failed: $e2, using fallback');
      content = utf8.decode(contentResponse.bodyBytes, allowMalformed: true);
    }
  }
  // ... 后续处理
}
```

**注意**: 使用 `gbk_codec` 而不是 `charset_converter`，因为后者在某些平台（如macOS）上没有原生实现。`gbk_codec` 是纯Dart实现，支持所有平台。

## 测试验证

### 测试1: API路径验证
```bash
curl -I "https://flutter.ombhrum.com/asset-manifest.json"
# 返回: HTTP/2 200 ✓
```

### 测试2: 文件列表验证
```bash
curl -s "https://flutter.ombhrum.com/asset-manifest.json" | grep -i "\.txt" | wc -l
# 返回: 1785 个txt文件 ✓
```

### 测试3: 文件访问验证
```bash
curl -L "https://flutter.ombhrum.com/assets/乾隆大藏经txt版/大乘五大部外重译经/第0122部～金光明最胜王经十卷.txt"
# 返回: HTTP/2 200 ✓
```

### 测试4: 编码验证
```bash
iconv -f GBK -t UTF-8 "assets/built_in/乾隆大藏经txt版/大乘五大部外重译经/第0122部～金光明最胜王经十卷.txt" | head -3
# 输出正确的中文内容 ✓
```

## 修复后的工作流程

1. 应用启动时，`CloudflareTextService` 尝试从 `flutter.ombhrum.com/asset-manifest.json` 获取文件列表
2. 随机选择一个txt文件
3. 下载文件内容
4. 尝试UTF-8解码，如果失败则使用GBK解码
5. 返回解码后的文本内容给视频流

## 相关文件

- `lib/services/cloudflare_text_service.dart` - 文本服务主文件
- `lib/features/video_feed/data/repository_impl/video_feed_repository_impl.dart` - 使用文本服务的地方
- `pubspec.yaml` - 依赖配置

## 后续建议

1. **考虑将GBK文件转换为UTF-8**: 在后端部署时将所有txt文件转换为UTF-8编码，可以简化前端处理逻辑
2. **添加缓存机制**: 缓存已下载的文本内容，减少网络请求
3. **添加错误重试**: 网络失败时自动重试
4. **优化文件选择**: 可以根据用户偏好或历史记录智能推荐文本

## 部署说明

修复后需要执行：
```bash
flutter pub get
flutter clean
flutter build [platform]
```

## 验证步骤

1. 运行应用
2. 进入视频流界面
3. 查看控制台日志，应该看到：
   - "Loaded cloud text: [文件名]"
   - "Successfully decoded GBK content"
4. 确认文本内容正确显示中文

---

**修复完成时间**: 2025-01-27  
**修复状态**: ✅ 已完成
