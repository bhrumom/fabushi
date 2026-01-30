# 3D地球优美轨迹实现指南

## 📖 概述

本指南介绍如何在Flutter应用中实现优美的3D地球传输轨迹动画，包括贝塞尔曲线路径、彗星效果和流畅的动画。

## 🎯 核心特性

### 1. 优美的弧线轨迹
- ✅ 二次/三次贝塞尔曲线
- ✅ 动态高度计算
- ✅ 自然的弧线路径

### 2. 彗星效果
- ✅ 白色核心亮点
- ✅ 彩色光晕
- ✅ 渐变拖尾
- ✅ 平滑动画

### 3. 性能优化
- ✅ 自动清理
- ✅ 内存管理
- ✅ 流畅60fps

## 🚀 快速开始

### 方式一：使用增强版组件（推荐）

```dart
import 'package:flutter/material.dart';
import 'widgets/enhanced_earth_globe_widget.dart';

class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  final GlobalKey<EnhancedEarthGlobeWidgetState> _globeKey = GlobalKey();

  void _sendBeam() {
    _globeKey.currentState?.addBeautifulTrajectory(
      fromLat: 39.9042,  // 北京
      fromLng: 116.4074,
      toLat: 40.7128,    // 纽约
      toLng: -74.0060,
      color: Colors.cyan,
      duration: Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: EnhancedEarthGlobeWidget(key: _globeKey),
          ),
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
}
```

### 方式二：使用现有组件（已优化）

```dart
import 'widgets/earth_globe_widget.dart';

class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  final GlobalKey<EarthGlobeWidgetState> _globeKey = GlobalKey();

  void _sendBeam() {
    // 使用国家代码
    _globeKey.currentState?.addTransferBeamByCountryCode(
      'CN',  // 中国
      'US',  // 美国
      color: Colors.blue,
      duration: Duration(seconds: 2),
    );
    
    // 或使用坐标
    _globeKey.currentState?.addTransferBeam(
      39.9042, 116.4074,  // 北京
      40.7128, -74.0060,  // 纽约
      color: Colors.cyan,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: EarthGlobeWidget(key: _globeKey),
      ),
    );
  }
}
```

## 🎨 自定义配置

### 调整轨迹高度

```dart
// 在 globe_math_utils.dart 中
static v.Vector3 calculateArcControlPoint(
  double startLat, double startLng,
  double endLat, double endLng,
  {double heightFactor = 0.4}  // 调整此值：0.2-0.6
) {
  // ...
}
```

### 调整彗星拖尾长度

```dart
// 在 enhanced_earth_globe_widget.dart 中
const tailLength = 12;  // 调整此值：8-20
```

### 调整动画速度

```dart
_globeKey.currentState?.addBeautifulTrajectory(
  // ...
  duration: Duration(seconds: 2),  // 1-5秒
);
```

### 自定义颜色

```dart
// 预设颜色
Colors.cyan      // 青色（默认）
Colors.blue      // 蓝色
Colors.purple    // 紫色
Colors.pink      // 粉色
Colors.orange    // 橙色
Colors.teal      // 青绿色

// 自定义颜色
Color.fromRGBO(100, 200, 255, 1.0)
```

## 📐 数学原理

### 贝塞尔曲线

**二次贝塞尔曲线**（用于简单弧线）：
```
B(t) = (1-t)² * P0 + 2(1-t)t * P1 + t² * P2
```

**三次贝塞尔曲线**（用于复杂路径）：
```
B(t) = (1-t)³ * P0 + 3(1-t)²t * P1 + 3(1-t)t² * P2 + t³ * P3
```

### 坐标转换

**经纬度 → 3D坐标**：
```dart
x = -(radius * sin(φ) * cos(θ))
y = radius * cos(φ)
z = radius * sin(φ) * sin(θ)

其中：
φ = (90 - lat) * π/180
θ = (lng + 180) * π/180
```

### 弧线高度计算

```dart
distance = 大圆距离(起点, 终点)
altitude = min(distance * 0.3 / 6371, 0.5)
```

## 🎬 动画技巧

### 1. 彗星头部（三层结构）

```dart
// 外层光晕（大、半透明）
size: 14, opacity: 0.6

// 中层光晕（中、较亮）
size: 10, opacity: 0.8

// 核心亮点（小、纯白）
size: 6, color: Colors.white
```

### 2. 拖尾渐变

```dart
for (int j = 1; j <= tailLength; j++) {
  opacity = 1.0 - (j / tailLength)  // 线性衰减
  size = maxSize - (j * 0.5)        // 尺寸递减
}
```

### 3. 脉冲效果

```dart
// 起点/终点脉冲
for (int i = 0; i < 6; i++) {
  size = 15 + i * 3      // 扩散
  alpha = 255 - i * 40   // 淡出
  delay = 100ms * i      // 延迟
}
```

## 🔧 工具类说明

### GlobeMathUtils

```dart
// 经纬度转3D坐标
v.Vector3 pos = GlobeMathUtils.latLngToVector3(lat, lng, altitude: 0.3);

// 计算距离
double dist = GlobeMathUtils.calculateDistance(lat1, lng1, lat2, lng2);

// 计算控制点
v.Vector3 control = GlobeMathUtils.calculateArcControlPoint(
  startLat, startLng, endLat, endLng,
  heightFactor: 0.4,
);

// 贝塞尔插值
v.Vector3 point = GlobeMathUtils.quadraticBezier(p0, p1, p2, t);
```

### TrajectoryPainter

```dart
// 自定义绘制器（用于2D Canvas）
CustomPaint(
  painter: TrajectoryPainter(
    animationValue: 0.5,  // 0.0 - 1.0
    start: startVector,
    end: endVector,
    control: controlVector,
    color: Colors.cyan,
    trailLength: 15,
    projectToScreen: (vec, size) => Offset(...),
  ),
)
```

## 📊 性能优化建议

### 1. 点的生命周期管理

```dart
// 添加点
_controller.addPoint(point);

// 延迟清理（避免内存泄漏）
Future.delayed(Duration(milliseconds: 300), () {
  if (!_isDisposed && mounted) {
    _controller.removePoint(pointId);
  }
});
```

### 2. 批量操作

```dart
// ❌ 不推荐：逐个添加
for (var point in points) {
  _controller.addPoint(point);
}

// ✅ 推荐：批量添加
_controller.addPoints(points);
```

### 3. 动画步数优化

```dart
// 短距离：30-40步
const steps = 30;

// 中距离：40-60步
const steps = 50;

// 长距离：60-80步
const steps = 70;
```

## 🎯 实战示例

### 示例1：全球广播

```dart
void broadcastToWorld() async {
  final countries = _coordService.getAllCoordinates();
  final china = _coordService.getByCountryCode('CN');
  
  for (var country in countries) {
    await Future.delayed(Duration(milliseconds: 500));
    _globeKey.currentState?.addBeautifulTrajectory(
      fromLat: china.latitude,
      fromLng: china.longitude,
      toLat: country.latitude,
      toLng: country.longitude,
    );
  }
}
```

### 示例2：自动播放

```dart
bool _isPlaying = false;

void toggleAutoPlay() {
  setState(() => _isPlaying = !_isPlaying);
  if (_isPlaying) _autoPlay();
}

void _autoPlay() async {
  while (_isPlaying && mounted) {
    _sendRandomBeam();
    await Future.delayed(Duration(milliseconds: 800));
  }
}
```

### 示例3：多彩轨迹

```dart
final colors = [
  Colors.cyan,
  Colors.blue,
  Colors.purple,
  Colors.pink,
];

void sendColorfulBeams() {
  for (int i = 0; i < colors.length; i++) {
    Future.delayed(Duration(milliseconds: i * 200), () {
      _globeKey.currentState?.addBeautifulTrajectory(
        fromLat: startLat,
        fromLng: startLng,
        toLat: endLat,
        toLng: endLng,
        color: colors[i],
      );
    });
  }
}
```

## 🐛 常见问题

### Q1: 轨迹不显示？
**A**: 检查坐标是否正确，确保 `_coordService.initialize()` 已调用。

### Q2: 动画卡顿？
**A**: 减少 `steps` 数量或增加 `stepDelay`。

### Q3: 内存泄漏？
**A**: 确保在 `dispose()` 中清理所有点和动画。

### Q4: 轨迹太平？
**A**: 增加 `heightFactor` 参数（0.3 → 0.5）。

### Q5: 颜色不明显？
**A**: 调整 `opacity` 和 `size` 参数。

## 📚 相关文件

```
lib/
├── widgets/
│   ├── earth_globe_widget.dart              # 原始组件（已优化）
│   ├── enhanced_earth_globe_widget.dart     # 增强版组件
│   ├── trajectory_painter.dart              # 轨迹绘制器
│   └── meteor_beam_painter.dart             # 流星绘制器
├── utils/
│   └── globe_math_utils.dart                # 数学工具类
├── screens/
│   └── beautiful_trajectory_demo_screen.dart # 演示屏幕
└── services/
    └── country_coordinates_service.dart      # 坐标服务
```

## 🎓 进阶技巧

### 1. 多段轨迹

```dart
// 中转路径：北京 → 东京 → 纽约
await addBeautifulTrajectory(fromLat: 39.9, fromLng: 116.4, toLat: 35.6, toLng: 139.7);
await Future.delayed(Duration(seconds: 1));
await addBeautifulTrajectory(fromLat: 35.6, fromLng: 139.7, toLat: 40.7, toLng: -74.0);
```

### 2. 轨迹跟随

```dart
// 相机跟随轨迹
_controller.focusOnCoordinates(
  GlobeCoordinates(currentLat, currentLng),
  zoom: 1.5,
  animationDuration: Duration(milliseconds: 100),
);
```

### 3. 交互式轨迹

```dart
// 点击地球添加轨迹
onGlobeTap: (GlobeCoordinates coords) {
  _globeKey.currentState?.addBeautifulTrajectory(
    fromLat: _lastTapLat,
    fromLng: _lastTapLng,
    toLat: coords.latitude,
    toLng: coords.longitude,
  );
  _lastTapLat = coords.latitude;
  _lastTapLng = coords.longitude;
}
```

## 🌟 最佳实践

1. **使用GlobalKey访问组件状态**
2. **合理设置动画时长**（2-4秒）
3. **及时清理资源**（避免内存泄漏）
4. **批量操作优于单个操作**
5. **使用颜色区分不同类型的传输**
6. **添加用户反馈**（声音、震动）

## 📞 技术支持

如有问题，请查看：
- 项目README: `README.md`
- 示例代码: `lib/screens/beautiful_trajectory_demo_screen.dart`
- API文档: 代码注释

---

**愿此功德回向法界众生，同证菩提！** 🙏
