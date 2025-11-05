import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import '../services/country_coordinates_service.dart';
import '../services/ip_location_service.dart';
import 'dart:math' as math;

class EarthGlobeWidget extends StatefulWidget {
  const EarthGlobeWidget({super.key});

  @override
  State<EarthGlobeWidget> createState() => EarthGlobeWidgetState();
}

class EarthGlobeWidgetState extends State<EarthGlobeWidget> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late FlutterEarthGlobeController _controller;
  bool _isDisposed = false;
  final Map<String, AnimationController> _beamAnimations = {};
  final CountryCoordinatesService _coordService = CountryCoordinatesService();
  final IPLocationService _ipLocationService = IPLocationService();
  final math.Random _random = math.Random();

  // 用户当前位置
  double? _userLatitude;
  double? _userLongitude;
  String? _userCountryCode;
  bool _isLocationInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = FlutterEarthGlobeController(
      rotationSpeed: 0.05,
      isRotating: true,
      isBackgroundFollowingSphereRotation: true,
    );
    // 延迟加载纹理，避免初始化时崩溃
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTextureSafely();
    });
    _initializeServices();
  }

  Future<void> _loadTextureSafely() async {
    try {
      if (!_isDisposed && mounted) {
        _controller.loadSurface(Image.asset('assets/earth_texture.jpg').image);
      }
    } catch (e) {
      debugPrint('⚠️ 加载地球纹理失败: $e');
    }
  }

  Future<void> _initializeServices() async {
    await _coordService.initialize();
    await _initializeUserLocation();
  }

  Future<void> _initializeUserLocation() async {
    try {
      final location = await _ipLocationService.getCurrentLocation();

      if (!mounted) return;

      if (location != null) {
        setState(() {
          _userLatitude = location.latitude;
          _userLongitude = location.longitude;
          _userCountryCode = location.countryCode;
          _isLocationInitialized = true;
        });

        // 添加用户当前位置标记
        _controller.addPoint(Point(
          id: 'user_location',
          coordinates: GlobeCoordinates(_userLatitude!, _userLongitude!),
          style: PointStyle(
            color: Colors.blue.shade400,
            size: 12,
          ),
          label: location.country,
          isLabelVisible: true,
          labelTextStyle: const TextStyle(
            color: Colors.cyan,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 6),
            ],
          ),
        ));

        print('用户位置已设置: ${location.country}, ${location.city}');
      } else {
        // IP定位失败，使用中国北京作为默认位置
        final china = _coordService.getByCountryCode('CN');
        if (china != null && mounted) {
          setState(() {
            _userLatitude = china.latitude;
            _userLongitude = china.longitude;
            _userCountryCode = 'CN';
            _isLocationInitialized = true;
          });

          _controller.addPoint(Point(
            id: 'user_location',
            coordinates: GlobeCoordinates(_userLatitude!, _userLongitude!),
            style: PointStyle(
              color: Colors.red.shade400,
              size: 12,
            ),
            label: '中国',
            isLabelVisible: true,
            labelTextStyle: const TextStyle(
              color: Colors.cyan,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 6),
              ],
            ),
          ));

          print('使用默认位置: 中国北京');
        }
      }
    } catch (e) {
      print('初始化用户位置失败: $e');
      if (!mounted) return;
      // 使用中国北京作为默认位置
      final china = _coordService.getByCountryCode('CN');
      if (china != null && mounted) {
        setState(() {
          _userLatitude = china.latitude;
          _userLongitude = china.longitude;
          _userCountryCode = 'CN';
          _isLocationInitialized = true;
        });
      }
    }
  }

  void addRandomTransferBeam({Color? color, Duration? duration}) {
    final countries = _coordService.getAllCoordinates();
    if (countries.isEmpty || !_isLocationInitialized) return;

    // 使用用户IP定位的位置作为起点
    final to = countries[_random.nextInt(countries.length)];

    addTransferBeam(
      _userLatitude!,
      _userLongitude!,
      to.latitude,
      to.longitude,
      color: color,
      duration: duration,
    );
  }

  void addTransferBeamByCountryCode(String fromCode, String toCode, {Color? color, Duration? duration}) {
    final from = _coordService.getByCountryCode(fromCode);
    final to = _coordService.getByCountryCode(toCode);

    if (from != null && to != null) {
      addTransferBeam(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
        color: color,
        duration: duration,
        fromLabel: from.countryName,
        toLabel: to.countryName,
      );
    }
  }

  Future<void> addTransferBeam(double fromLat, double fromLng, double toLat, double toLng, {Color? color, Duration? duration, String? fromLabel, String? toLabel}) async {
    if (!_isDisposed && mounted) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final beamId = 'beam_$timestamp';
      final transferDuration = duration ?? const Duration(seconds: 2);

      // 获取国家名称（如果没有提供）
      if (fromLabel == null) {
        final fromCountry = _coordService.getByCoordinates(fromLat, fromLng);
        fromLabel = fromCountry?.countryName;
      }
      if (toLabel == null) {
        final toCountry = _coordService.getByCoordinates(toLat, toLng);
        toLabel = toCountry?.countryName;
      }

      // 添加起点标记（带国家名称）
      _controller.addPoint(Point(
        id: 'from_$timestamp',
        coordinates: GlobeCoordinates(fromLat, fromLng),
        style: PointStyle(
          color: Colors.red.shade400,
          size: 8,
        ),
        label: fromLabel,
        isLabelVisible: true,
        labelTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 6),
          ],
        ),
      ));

      // 添加终点标记（带国家名称）
      _controller.addPoint(Point(
        id: 'to_$timestamp',
        coordinates: GlobeCoordinates(toLat, toLng),
        style: PointStyle(
          color: Colors.green.shade400,
          size: 6,
        ),
        label: toLabel,
        isLabelVisible: true,
        labelTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 6),
          ],
        ),
      ));

      // 添加起点的脉冲效果
      await _createPulseEffect(fromLat, fromLng, 'from_pulse_$timestamp', Colors.red.shade400);

      // 流星动画
      await _animateMovingLight(fromLat, fromLng, toLat, toLng, beamId, color ?? Colors.cyan, transferDuration);

      // 添加终点的脉冲效果
      await _createPulseEffect(toLat, toLng, 'to_pulse_$timestamp', Colors.green.shade400);

      // 清除轨迹
      _controller.removePoint('from_$timestamp');
      _controller.removePoint('to_$timestamp');
    }
  }

  Future<void> _animateMovingLight(double fromLat, double fromLng, double toLat, double toLng, String beamId, Color color, Duration duration) async {
    const steps = 80;
    final stepDelay = Duration(milliseconds: duration.inMilliseconds ~/ steps);
    const tailLength = 20;

    // 计算优美的弧线路径控制点
    final midLat = (fromLat + toLat) / 2;
    final midLng = (fromLng + toLng) / 2;

    // 平衡的弧线高度（立体感 + 连续性）
    final distance = _calculateDistance(fromLat, fromLng, toLat, toLng);
    final arcHeight = math.min(distance * 0.4, 40); // 平衡高度

    // 计算垂直向上的偏移
    final angle = math.atan2(toLat - fromLat, toLng - fromLng);
    final arcLat = midLat + arcHeight * math.cos(angle + math.pi / 2);
    final arcLng = midLng + arcHeight * math.sin(angle + math.pi / 2);

    for (int i = 0; i <= steps; i++) {
      if (_isDisposed || !mounted) break;

      final t = i / steps;

      // 使用二次贝塞尔曲线计算弧线路径
      final lat = _quadraticBezier(fromLat, arcLat, toLat, t);
      final lng = _quadraticBezier(fromLng, arcLng, toLng, t);

      // 添加流星头部（白色核心 + 彩色光晕）
      final headId = '${beamId}_head_$i';
      
      // 最外层光晕（大范围辉光）
      _controller.addPoint(Point(
        id: '${headId}_glow_outer',
        coordinates: GlobeCoordinates(lat, lng),
        style: PointStyle(
          color: color.withOpacity(0.3),
          size: 20,
        ),
      ));
      
      // 中层彩色光晕
      _controller.addPoint(Point(
        id: '${headId}_glow',
        coordinates: GlobeCoordinates(lat, lng),
        style: PointStyle(
          color: color.withOpacity(0.7),
          size: 14,
        ),
      ));
      
      // 核心白色亮点
      _controller.addPoint(Point(
        id: headId,
        coordinates: GlobeCoordinates(lat, lng),
        style: PointStyle(
          color: Colors.white,
          size: 10,
        ),
      ));

      // 添加流星拖尾（渐变）
      for (int j = 1; j <= tailLength; j++) {
        if (i - j < 0) continue;

        final tailT = (i - j) / steps;
        final tailLat = _quadraticBezier(fromLat, arcLat, toLat, tailT);
        final tailLng = _quadraticBezier(fromLng, arcLng, toLng, tailT);
        final tailId = '${beamId}_tail_${i}_$j';
        final opacity = (1 - j / tailLength);

        _controller.addPoint(Point(
          id: tailId,
          coordinates: GlobeCoordinates(tailLat, tailLng),
          style: PointStyle(
            color: color.withOpacity(opacity * 0.8),
            size: (14 - j * 0.6).clamp(4, 14),
          ),
        ));

        // 移除拖尾点
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_isDisposed && mounted) {
            try {
              _controller.removePoint(tailId);
            } catch (_) {}
          }
        });
      }

      // 移除头部点（包括所有光晕）
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!_isDisposed && mounted) {
          try {
            _controller.removePoint(headId);
            _controller.removePoint('${headId}_glow');
            _controller.removePoint('${headId}_glow_outer');
          } catch (_) {}
        }
      });

      await Future.delayed(stepDelay);
    }

    // 清理所有残留点
    await Future.delayed(const Duration(milliseconds: 500));
    if (!_isDisposed && mounted) {
      for (int i = 0; i <= steps; i++) {
        try {
          _controller.removePoint('${beamId}_head_$i');
          for (int j = 1; j <= tailLength; j++) {
            _controller.removePoint('${beamId}_tail_${i}_$j');
          }
        } catch (_) {}
      }
    }
  }

  // 计算两点间的大圆距离
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371; // 地球半径（公里）
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  // 角度转弧度
  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  // 二次贝塞尔曲线插值（优化版）
  double _quadraticBezier(double p0, double p1, double p2, double t) {
    final u = 1 - t;
    return u * u * p0 + 2 * u * t * p1 + t * t * p2;
  }

  // 三次贝塞尔曲线插值（更平滑）
  double _cubicBezier(double p0, double p1, double p2, double p3, double t) {
    final u = 1 - t;
    final tt = t * t;
    final uu = u * u;
    return uu * u * p0 + 3 * uu * t * p1 + 3 * u * tt * p2 + tt * t * p3;
  }

  // 创建脉冲效果
  Future<void> _createPulseEffect(double lat, double lng, String pulseId, Color color) async {
    const pulseSteps = 6;
    final pulseDelay = const Duration(milliseconds: 100);

    for (int i = 0; i < pulseSteps; i++) {
      if (_isDisposed || !mounted) break;

      final size = 15 + i * 3;
      final alpha = 255 - (i * 40);

      _controller.addPoint(Point(
        id: '${pulseId}_$i',
        coordinates: GlobeCoordinates(lat, lng),
        style: PointStyle(
          color: color.withAlpha(alpha.clamp(50, 255)),
          size: size.toDouble(),
        ),
      ));

      // 逐步移除脉冲环
      Future.delayed(pulseDelay * 2, () {
        if (!_isDisposed && mounted) {
          try {
            _controller.removePoint('${pulseId}_$i');
          } catch (_) {}
        }
      });

      await Future.delayed(pulseDelay);
    }
  }

  void clearBeams() {
    if (!_isDisposed && mounted) {
      // 清除所有点和连接，保留用户位置标记
      for (var point in List.from(_controller.points)) {
        if (point.id != 'user_location') {
          _controller.removePoint(point.id);
        }
      }
      for (var conn in List.from(_controller.connections)) {
        _controller.removePointConnection(conn.id);
      }
    }
  }

  // 重新定位用户位置
  Future<void> relocateUser() async {
    _ipLocationService.clearCache();
    await _initializeUserLocation();
  }

  // 获取用户位置信息
  String getUserLocationInfo() {
    if (!_isLocationInitialized) {
      return '位置定位中...';
    }

    if (_userCountryCode == 'CN') {
      return '中国北京';
    }

    return 'IP位置 ($_userCountryCode)';
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      for (var controller in _beamAnimations.values) {
        controller.dispose();
      }
      _beamAnimations.clear();
      try {
        _controller.dispose();
      } catch (e) {
        // 忽略重复dispose错误
      }
    }
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以保持状态
    
    // 添加错误边界
    return Builder(
      builder: (context) {
        try {
          return FlutterEarthGlobe(
            controller: _controller,
            radius: 150,
          );
        } catch (e) {
          debugPrint('❌ FlutterEarthGlobe 渲染失败: $e');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.public_off, color: Colors.white54, size: 64),
                const SizedBox(height: 16),
                Text(
                  '地球组件暂时不可用',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
