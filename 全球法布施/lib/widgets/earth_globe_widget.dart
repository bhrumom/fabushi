import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:flutter_earth_globe/point_connection.dart';
import 'package:flutter_earth_globe/point_connection_style.dart';
import '../services/country_coordinates_service.dart';
import '../services/ip_location_service.dart';
import 'dart:math' as math;

class EarthGlobeWidget extends StatefulWidget {
  const EarthGlobeWidget({super.key});

  @override
  State<EarthGlobeWidget> createState() => EarthGlobeWidgetState();
}

class EarthGlobeWidgetState extends State<EarthGlobeWidget>
    with AutomaticKeepAliveClientMixin {
  late FlutterEarthGlobeController _controller;
  bool _isDisposed = false;
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
    try {
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
    } catch (e) {
      debugPrint('⚠️ 地球组件初始化失败: $e');
      // 初始化失败时创建一个基本的控制器
      _controller = FlutterEarthGlobeController();
    }
  }

  Future<void> _loadTextureSafely() async {
    try {
      if (!_isDisposed && mounted) {
        // 安全加载纹理，添加错误处理
        final image = Image.asset(
          'assets/earth_texture.jpg',
          errorBuilder: (context, error, stackTrace) {
            debugPrint('⚠️ 地球纹理加载失败: $error');
            return Container(
              width: 100,
              height: 100,
              color: Colors.blue.shade900,
              child: const Icon(Icons.public, color: Colors.white),
            );
          },
        );
        _controller.loadSurface(image.image);
      }
    } catch (e) {
      debugPrint('⚠️ 加载地球纹理失败: $e');
      // 纹理加载失败时不阻止组件渲染
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
        _controller.addPoint(
          Point(
            id: 'user_location',
            coordinates: GlobeCoordinates(_userLatitude!, _userLongitude!),
            style: PointStyle(color: Colors.blue.shade400, size: 12),
            label: location.country,
            isLabelVisible: true,
            labelTextStyle: const TextStyle(
              color: Colors.cyan,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
        );

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

          _controller.addPoint(
            Point(
              id: 'user_location',
              coordinates: GlobeCoordinates(_userLatitude!, _userLongitude!),
              style: PointStyle(color: Colors.red.shade400, size: 12),
              label: '中国',
              isLabelVisible: true,
              labelTextStyle: const TextStyle(
                color: Colors.cyan,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
          );

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

  void addTransferBeamByCountryCode(
    String fromCode,
    String toCode, {
    Color? color,
    Duration? duration,
  }) {
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

  // 当前活跃的轨迹（只保留一条，代表当前正在发送的国家）
  String? _currentConnectionId;
  String? _currentDestPointId;
  
  // 发送状态管理 - 控制地球旋转和视角
  bool _isSending = false;

  Future<void> addTransferBeam(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng, {
    Color? color,
    Duration? duration,
    String? fromLabel,
    String? toLabel,
  }) async {
    if (_isDisposed || !mounted) return;

    // 获取国家名称（如果没有提供）
    if (toLabel == null) {
      final toCountry = _coordService.getByCoordinates(toLat, toLng);
      toLabel = toCountry?.countryName;
    }

    // 发送时暂停地球自动旋转，确保轨迹可见
    if (!_isSending) {
      _isSending = true;
      _controller.stopRotation();
      debugPrint('🌍 暂停地球旋转，开始显示轨迹');
    }

    // 移除上一条轨迹（上一个国家发送完成了）
    if (_currentConnectionId != null) {
      _safeRemoveConnection(_currentConnectionId!);
    }
    if (_currentDestPointId != null) {
      _safeRemovePoint(_currentDestPointId!);
    }

    // 生成新的ID
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentConnectionId = 'conn_$timestamp';
    _currentDestPointId = 'dest_$timestamp';

    // 计算轨迹中点，用于聚焦视角
    final startLat = _userLatitude ?? fromLat;
    final startLng = _userLongitude ?? fromLng;
    final midLat = (startLat + toLat) / 2;
    final midLng = (startLng + toLng) / 2;
    
    // 聚焦到轨迹中点，确保轨迹始终可见
    // 视角缓慢移动，速度与自转类似，更平滑自然
    _controller.focusOnCoordinates(
      GlobeCoordinates(midLat, midLng),
      animate: true,
      duration: const Duration(milliseconds: 2000),
    );

    // 添加目标点（绿色标记 + 国家名称）
    _controller.addPoint(
      Point(
        id: _currentDestPointId!,
        coordinates: GlobeCoordinates(toLat, toLng),
        style: PointStyle(color: Colors.greenAccent, size: 8),
        label: toLabel,
        isLabelVisible: true,
        labelTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
    );

    // 添加从用户位置到目标的连线
    _controller.addPointConnection(
      PointConnection(
        id: _currentConnectionId!,
        start: GlobeCoordinates(startLat, startLng),
        end: GlobeCoordinates(toLat, toLng),
        isMoving: true,
        style: PointConnectionStyle(
          type: PointConnectionType.dashed,
          color: color ?? Colors.cyan,
          lineWidth: 1.5,
          dashSize: 4,
        ),
      ),
    );
    
    // 轨迹会一直显示，直到下一个国家开始发送或调用 clearBeams
  }

  // 安全移除点
  void _safeRemovePoint(String pointId) {
    if (!_isDisposed && mounted) {
      try {
        _controller.removePoint(pointId);
      } catch (_) {}
    }
  }

  // 安全移除连线
  void _safeRemoveConnection(String connId) {
    if (!_isDisposed && mounted) {
      try {
        _controller.removePointConnection(connId);
      } catch (_) {}
    }
  }

  void clearBeams() {
    if (!_isDisposed && mounted) {
      // 清除当前轨迹
      if (_currentConnectionId != null) {
        _safeRemoveConnection(_currentConnectionId!);
        _currentConnectionId = null;
      }
      if (_currentDestPointId != null) {
        _safeRemovePoint(_currentDestPointId!);
        _currentDestPointId = null;
      }
      
      // 清除所有其他点和连接，保留用户位置标记
      for (var point in List.from(_controller.points)) {
        if (point.id != 'user_location') {
          _controller.removePoint(point.id);
        }
      }
      for (var conn in List.from(_controller.connections)) {
        _controller.removePointConnection(conn.id);
      }
      
      // 恢复地球旋转
      if (_isSending) {
        _isSending = false;
        _controller.startRotation();
        debugPrint('🌍 清除轨迹，恢复地球旋转');
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
      _currentConnectionId = null;
      _currentDestPointId = null;
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
          return FlutterEarthGlobe(controller: _controller, radius: 150);
        } catch (e) {
          debugPrint('❌ FlutterEarthGlobe 渲染失败: $e');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.public_off, color: Colors.white54, size: 64),
                const SizedBox(height: 16),
                Text('地球组件暂时不可用', style: const TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
          );
        }
      },
    );
  }
}
