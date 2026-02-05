# Flutter Earth Globe 实时轨迹显示 - 完整使用指南

## 📖 目录

1. [快速开始](#快速开始)
2. [核心功能](#核心功能)
3. [API 参考](#api-参考)
4. [使用示例](#使用示例)
5. [全球城市坐标](#全球城市坐标)
6. [自定义配置](#自定义配置)
7. [性能优化](#性能优化)
8. [故障排除](#故障排除)

---

## 🚀 快速开始

### 1. 安装依赖

确保 `pubspec.yaml` 中已添加：

```yaml
dependencies:
  flutter_earth_globe: ^1.0.7
```

运行安装命令：

```bash
flutter pub get
```

### 2. 准备地球纹理

将地球纹理图片放在 `assets/earth_texture.jpg`，并在 `pubspec.yaml` 中声明：

```yaml
flutter:
  assets:
    - assets/earth_texture.jpg
```

### 3. 基础使用

```dart
import 'package:flutter/material.dart';
import '../widgets/earth_globe_widget.dart';

class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  final GlobalKey<EarthGlobeWidgetState> _globeKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 地球组件
          EarthGlobeWidget(key: _globeKey),
          
          // 控制按钮
          Positioned(
            bottom: 20,
            child: ElevatedButton(
              onPressed: _sendBeam,
              child: Text('发送'),
            ),
          ),
        ],
      ),
    );
  }

  void _sendBeam() {
    // 从北京发送到纽约
    _globeKey.currentState?.addTransferBeam(
      39.9042, 116.4074,  // 北京
      40.7128, -74.0060,  // 纽约
      color: Colors.cyan,
    );
  }
}
```

---

## 🎯 核心功能

### 1. 添加传输轨迹

```dart
_globeKey.currentState?.addTransferBeam(
  fromLat,    // 起点纬度 (-90 到 90)
  fromLng,    // 起点经度 (-180 到 180)
  toLat,      // 终点纬度
  toLng,      // 终点经度
  color: Colors.cyan,  // 可选：轨迹颜色
);
```

### 2. 批量发送

```dart
Future<void> sendToMultipleCities() async {
  final destinations = [
    {'lat': 37.7749, 'lng': -122.4194, 'color': Colors.cyan},
    {'lat': 51.5074, 'lng': -0.1278, 'color': Colors.blue},
    {'lat': 35.6762, 'lng': 139.6503, 'color': Colors.purple},
  ];

  for (var dest in destinations) {
    _globeKey.currentState?.addTransferBeam(
      39.9042, 116.4074,
      dest['lat'], dest['lng'],
      color: dest['color'],
    );
    await Future.delayed(Duration(milliseconds: 300));
  }
}
```

### 3. 清除轨迹

```dart
_globeKey.currentState?.clearBeams();
```

---

## 📚 API 参考

### EarthGlobeWidget

主要的地球显示组件。

**构造函数：**

```dart
const EarthGlobeWidget({Key? key})
```

**State 方法：**

| 方法 | 参数 | 说明 |
|------|------|------|
| `addTransferBeam` | `fromLat, fromLng, toLat, toLng, {Color? color}` | 添加一条传输轨迹 |
| `clearBeams` | 无 | 清除所有轨迹 |

### FlutterEarthGlobeController

控制地球行为的控制器。

**参数：**

```dart
FlutterEarthGlobeController({
  double rotationSpeed = 0.05,        // 旋转速度
  bool isRotating = true,             // 是否自动旋转
  bool isBackgroundFollowingSphereRotation = true,  // 背景是否跟随
  ImageProvider? surface,             // 地球表面纹理
})
```

### Point

地球上的标记点。

```dart
Point(
  id: 'unique_id',
  coordinates: GlobeCoordinates(latitude, longitude),
  style: PointStyle(
    color: Colors.cyan,
    size: 4,
  ),
)
```

### PointConnection

连接两个点的线。

```dart
PointConnection(
  startPoint: fromPoint,
  endPoint: toPoint,
  style: ConnectionStyle(
    color: Colors.cyan,
    width: 2.0,
    dotted: false,
  ),
  animateDraw: true,  // 启用绘制动画
)
```

---

## 💡 使用示例

### 示例 1: 简单的点对点传输

```dart
void sendToOneCity() {
  _globeKey.currentState?.addTransferBeam(
    39.9042, 116.4074,  // 北京
    37.7749, -122.4194, // 旧金山
    color: Colors.cyan,
  );
}
```

### 示例 2: 多城市依次发送

```dart
Future<void> sendToMultipleCities() async {
  final cities = [
    {'name': '旧金山', 'lat': 37.7749, 'lng': -122.4194},
    {'name': '伦敦', 'lat': 51.5074, 'lng': -0.1278},
    {'name': '东京', 'lat': 35.6762, 'lng': 139.6503},
  ];

  for (var city in cities) {
    print('发送到 ${city['name']}');
    _globeKey.currentState?.addTransferBeam(
      39.9042, 116.4074,
      city['lat']!, city['lng']!,
    );
    await Future.delayed(Duration(milliseconds: 300));
  }
}
```

### 示例 3: 彩色轨迹

```dart
void sendWithColors() {
  final colors = [
    Colors.cyan,
    Colors.blue,
    Colors.purple,
    Colors.green,
    Colors.orange,
  ];

  for (var i = 0; i < destinations.length; i++) {
    _globeKey.currentState?.addTransferBeam(
      39.9042, 116.4074,
      destinations[i]['lat'], destinations[i]['lng'],
      color: colors[i % colors.length],
    );
  }
}
```

### 示例 4: 带进度显示

```dart
Future<void> sendWithProgress() async {
  setState(() => _isSending = true);

  for (var i = 0; i < cities.length; i++) {
    setState(() {
      _currentCity = cities[i]['name'];
      _progress = (i + 1) / cities.length;
    });

    _globeKey.currentState?.addTransferBeam(
      39.9042, 116.4074,
      cities[i]['lat'], cities[i]['lng'],
    );

    await Future.delayed(Duration(milliseconds: 300));
  }

  setState(() => _isSending = false);
}
```

---

## 🌍 全球城市坐标

### 亚洲

| 城市 | 纬度 | 经度 | 代码 |
|------|------|------|------|
| 🇨🇳 北京 | 39.9042 | 116.4074 | `39.9042, 116.4074` |
| 🇯🇵 东京 | 35.6762 | 139.6503 | `35.6762, 139.6503` |
| 🇰🇷 首尔 | 37.5665 | 126.9780 | `37.5665, 126.9780` |
| 🇸🇬 新加坡 | 1.3521 | 103.8198 | `1.3521, 103.8198` |
| 🇮🇳 新德里 | 28.6139 | 77.2090 | `28.6139, 77.2090` |
| 🇹🇭 曼谷 | 13.7563 | 100.5018 | `13.7563, 100.5018` |
| 🇮🇩 雅加达 | -6.2088 | 106.8456 | `-6.2088, 106.8456` |

### 欧洲

| 城市 | 纬度 | 经度 | 代码 |
|------|------|------|------|
| 🇬🇧 伦敦 | 51.5074 | -0.1278 | `51.5074, -0.1278` |
| 🇫🇷 巴黎 | 48.8566 | 2.3522 | `48.8566, 2.3522` |
| 🇩🇪 柏林 | 52.5200 | 13.4050 | `52.5200, 13.4050` |
| 🇷🇺 莫斯科 | 55.7558 | 37.6173 | `55.7558, 37.6173` |
| 🇮🇹 罗马 | 41.9028 | 12.4964 | `41.9028, 12.4964` |
| 🇪🇸 马德里 | 40.4168 | -3.7038 | `40.4168, -3.7038` |

### 美洲

| 城市 | 纬度 | 经度 | 代码 |
|------|------|------|------|
| 🇺🇸 纽约 | 40.7128 | -74.0060 | `40.7128, -74.0060` |
| 🇺🇸 旧金山 | 37.7749 | -122.4194 | `37.7749, -122.4194` |
| 🇺🇸 洛杉矶 | 34.0522 | -118.2437 | `34.0522, -118.2437` |
| 🇨🇦 多伦多 | 43.6532 | -79.3832 | `43.6532, -79.3832` |
| 🇧🇷 圣保罗 | -23.5505 | -46.6333 | `-23.5505, -46.6333` |
| 🇲🇽 墨西哥城 | 19.4326 | -99.1332 | `19.4326, -99.1332` |

### 大洋洲

| 城市 | 纬度 | 经度 | 代码 |
|------|------|------|------|
| 🇦🇺 悉尼 | -33.8688 | 151.2093 | `-33.8688, 151.2093` |
| 🇦🇺 墨尔本 | -37.8136 | 144.9631 | `-37.8136, 144.9631` |
| 🇳🇿 奥克兰 | -36.8485 | 174.7633 | `-36.8485, 174.7633` |

### 非洲

| 城市 | 纬度 | 经度 | 代码 |
|------|------|------|------|
| 🇿🇦 开普敦 | -33.9249 | 18.4241 | `-33.9249, 18.4241` |
| 🇪🇬 开罗 | 30.0444 | 31.2357 | `30.0444, 31.2357` |
| 🇰🇪 内罗毕 | -1.2864 | 36.8172 | `-1.2864, 36.8172` |

---

## ⚙️ 自定义配置

### 调整地球大小

```dart
FlutterEarthGlobe(
  controller: _controller,
  radius: 180,  // 默认 150，可根据屏幕调整
  points: _points,
  connections: _connections,
)
```

### 调整旋转速度

```dart
FlutterEarthGlobeController(
  rotationSpeed: 0.1,  // 默认 0.05，值越大转得越快
  isRotating: true,
)
```

### 自定义轨迹样式

```dart
ConnectionStyle(
  color: Colors.cyan,
  width: 3.0,        // 线宽
  dotted: false,     // 是否虚线
)
```

### 自定义点样式

```dart
PointStyle(
  color: Colors.orange,
  size: 6,           // 点的大小
)
```

---

## ⚡ 性能优化

### 1. 限制轨迹数量

```dart
// 保持轨迹数量在合理范围
if (_connections.length > 20) {
  _connections.removeAt(0);
  _points.removeRange(0, 2);
}
```

### 2. 根据设备调整

```dart
// 根据屏幕大小调整地球半径
double getRadius(BuildContext context) {
  final size = MediaQuery.of(context).size;
  return size.width < 600 ? 120 : 180;
}
```

### 3. 延迟添加

```dart
// 避免同时添加过多轨迹
for (var city in cities) {
  addBeam(city);
  await Future.delayed(Duration(milliseconds: 200));
}
```

### 4. 及时清理

```dart
// 传输完成后清理
@override
void dispose() {
  _globeKey.currentState?.clearBeams();
  super.dispose();
}
```

---

## 🔧 故障排除

### 问题 1: 地球不显示

**可能原因：**
- 纹理图片路径错误
- 未运行 `flutter pub get`
- 资源未在 `pubspec.yaml` 中声明

**解决方案：**
```bash
# 1. 确认资源路径
ls assets/earth_texture.jpg

# 2. 重新获取依赖
flutter pub get

# 3. 清理缓存
flutter clean
flutter pub get
```

### 问题 2: 轨迹不显示

**可能原因：**
- 坐标格式错误
- GlobalKey 未正确绑定
- setState 未调用

**解决方案：**
```dart
// 确保坐标在有效范围内
assert(lat >= -90 && lat <= 90);
assert(lng >= -180 && lng <= 180);

// 确保 key 正确绑定
EarthGlobeWidget(key: _globeKey)

// 确保在 mounted 状态下调用
if (mounted) {
  _globeKey.currentState?.addTransferBeam(...);
}
```

### 问题 3: 性能问题

**解决方案：**
```dart
// 1. 减少轨迹数量
if (_connections.length > 15) {
  clearBeams();
}

// 2. 降低旋转速度
rotationSpeed: 0.03

// 3. 减小地球半径
radius: 120
```

### 问题 4: 内存泄漏

**解决方案：**
```dart
@override
void dispose() {
  if (!_isDisposed) {
    _isDisposed = true;
    _controller.dispose();
  }
  super.dispose();
}
```

---

## 📱 运行演示

### 运行主界面

```bash
flutter run -d chrome
```

### 运行演示界面

修改 `lib/main.dart`：

```dart
import 'package:global_dharma_sharing/screens/earth_globe_demo_screen.dart';

void main() {
  runApp(MaterialApp(
    home: EarthGlobeDemoScreen(),
  ));
}
```

然后运行：

```bash
flutter run -d chrome  # Web
flutter run -d android # Android
flutter run -d ios     # iOS
```

---

## 🎓 进阶技巧

### 1. 动态颜色

```dart
Color getColorByDistance(double distance) {
  if (distance < 5000) return Colors.green;
  if (distance < 10000) return Colors.yellow;
  return Colors.red;
}
```

### 2. 分组发送

```dart
Future<void> sendByContinent(String continent) async {
  final cities = allCities.where((c) => c.continent == continent);
  for (var city in cities) {
    addBeam(city);
    await Future.delayed(Duration(milliseconds: 250));
  }
}
```

### 3. 实时统计

```dart
int _totalSent = 0;
int _successCount = 0;

void trackSending() {
  _totalSent++;
  // 发送成功后
  _successCount++;
  print('成功率: ${(_successCount / _totalSent * 100).toStringAsFixed(1)}%');
}
```

---

## 📖 参考资源

- [flutter_earth_globe 官方文档](https://pub.dev/packages/flutter_earth_globe)
- [API 文档](https://pub.dev/documentation/flutter_earth_globe/latest/)
- [GitHub 仓库](https://github.com/Pana-g/flutter_earth_globe)
- [示例代码](https://pub.dev/packages/flutter_earth_globe/example)

---

**愿此功德回向法界众生，同证菩提！** 🙏
