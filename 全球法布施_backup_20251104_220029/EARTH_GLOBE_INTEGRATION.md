# Flutter Earth Globe 集成说明

## 概述

已将项目的 3D 地球可视化从 Three.js (Web) 迁移到 `flutter_earth_globe` 包，这是一个纯 Flutter 实现的 3D 地球组件。

## 优势

1. **跨平台统一**: 所有平台（Android、iOS、Web、macOS、Windows、Linux）使用相同的代码
2. **性能优化**: 原生 Flutter 渲染，性能更好
3. **易于维护**: 不需要维护 HTML/JavaScript 代码
4. **集成简单**: 直接使用 Flutter Widget，无需 iframe 或 WebView

## 安装

已在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  flutter_earth_globe: ^1.0.7
```

运行以下命令安装：

```bash
flutter pub get
```

## 核心组件

### EarthGlobeWidget

位置: `lib/widgets/earth_globe_widget.dart`

这是封装了 `flutter_earth_globe` 的主要组件，提供以下功能：

- 自动旋转的 3D 地球
- 添加传输光束动画
- 清除光束
- 自定义地球表面纹理

### 主要方法

```dart
// 添加传输标记（v1.0.7 不支持连接线）
void addTransferBeam(double fromLat, double fromLng, double toLat, double toLng)

// 清除所有标记
void clearBeams()
```

**注意**: flutter_earth_globe v1.0.7 提供基础的 3D 地球显示功能，不支持连接线动画。主要功能包括：
- 自动旋转的 3D 地球
- 自定义地球表面纹理
- 流畅的交互体验

## 使用示例

在 `GlobeHomeScreen` 中的使用：

```dart
// 1. 创建 GlobalKey
final GlobalKey<EarthGlobeWidgetState> _globeKey = GlobalKey();

// 2. 在 Widget 树中使用
EarthGlobeWidget(key: _globeKey)

// 3. 添加传输光束
_globeKey.currentState?.addTransferBeam(
  39.9042, 116.4074,  // 起点（北京）
  37.7749, -122.4194, // 终点（旧金山）
);

// 4. 清除光束
_globeKey.currentState?.clearBeams();
```

## 自定义配置

### 地球控制器参数

在 `earth_globe_widget.dart` 中可以自定义：

```dart
FlutterEarthGlobeController(
  rotationSpeed: 0.05,              // 旋转速度
  isRotating: true,                 // 是否自动旋转
  isBackgroundFollowingSphereRotation: true, // 背景是否跟随旋转
  surface: Image.network('...').image, // 地球表面纹理
)
```

### 地球样式

```dart
FlutterEarthGlobeController(
  rotationSpeed: 0.05,    // 旋转速度
  isRotating: true,       // 是否自动旋转
  surface: Image.network('...').image, // 地球纹理
)
```

## 传输动画流程

1. 用户选择经文
2. 点击"开始发送"
3. 清除之前的光束
4. 依次添加到多个国家的光束（带延迟效果）
5. 显示进度条
6. 完成后显示成功提示

## 支持的国家坐标

当前配置的目标国家：

- 🇺🇸 美国旧金山: (37.7749, -122.4194)
- 🇬🇧 英国伦敦: (51.5074, -0.1278)
- 🇯🇵 日本东京: (35.6762, 139.6503)
- 🇦🇺 澳大利亚悉尼: (-33.8688, 151.2093)
- 🇮🇳 印度新德里: (28.6139, 77.2090)
- 🇧🇷 巴西圣保罗: (-23.5505, -46.6333)

## 性能优化建议

1. **限制光束数量**: 不要同时显示过多光束（建议 < 20）
2. **及时清理**: 传输完成后清除光束
3. **调整半径**: 根据屏幕大小调整地球半径

```dart
FlutterEarthGlobe(
  controller: _controller,
  radius: 150, // 可根据设备调整
  connections: _connections,
)
```

## 故障排除

### 问题：地球不显示

**解决方案**:
- 确保已运行 `flutter pub get`
- 检查网络连接（地球纹理从网络加载）
- 查看控制台错误信息

### 问题：光束不显示

**解决方案**:
- 确保坐标格式正确（纬度: -90 到 90，经度: -180 到 180）
- 检查 `setState` 是否被调用
- 确认 GlobalKey 正确绑定

### 问题：性能问题

**解决方案**:
- 减少光束数量
- 降低旋转速度
- 减小地球半径

## 未来扩展

可以添加的功能：

1. **标记点**: 在地球上显示特定位置的标记
2. **热力图**: 显示传输密度
3. **实时数据**: 连接真实的传输数据
4. **交互控制**: 用户可以手动旋转、缩放地球
5. **自定义纹理**: 使用自定义的地球表面图片

## 参考资源

- [flutter_earth_globe 官方文档](https://pub.dev/packages/flutter_earth_globe)
- [示例代码](https://pub.dev/packages/flutter_earth_globe/example)
- [API 文档](https://pub.dev/documentation/flutter_earth_globe/latest/)

## 运行测试

```bash
# Web
flutter run -d chrome

# Android
flutter run -d android

# iOS
flutter run -d ios

# macOS
flutter run -d macos
```

---

**愿此功德回向法界众生，同证菩提！** 🙏
