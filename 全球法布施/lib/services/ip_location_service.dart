import 'dart:convert';
import 'package:http/http.dart' as http;

class IPLocation {
  final String ip;
  final String country;
  final String countryCode;
  final String region;
  final String city;
  final double latitude;
  final double longitude;

  IPLocation({
    required this.ip,
    required this.country,
    required this.countryCode,
    required this.region,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  factory IPLocation.fromJson(Map<String, dynamic> json) {
    return IPLocation(
      ip: json['query'] ?? json['ip'] ?? '',
      country: json['country'] ?? '',
      countryCode: json['countryCode'] ?? '',
      region: json['regionName'] ?? json['region'] ?? '',
      city: json['city'] ?? '',
      latitude: _parseDouble(json['lat']),
      longitude: _parseDouble(json['lon']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}

class IPLocationService {
  static final IPLocationService _instance = IPLocationService._internal();
  factory IPLocationService() => _instance;
  IPLocationService._internal();

  IPLocation? _cachedLocation;
  DateTime? _lastFetchTime;
  static const Duration _cacheValidity = const Duration(hours: 1);

  Future<IPLocation?> getCurrentLocation() async {
    // 检查缓存是否有效
    if (_cachedLocation != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheValidity) {
      return _cachedLocation;
    }

    try {
      // 使用免费的IP定位服务
      final response = await http
          .get(
            Uri.parse(
              'http://ip-api.com/json/?fields=status,message,country,countryCode,region,city,lat,lon,query',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          _cachedLocation = IPLocation.fromJson(data);
          _lastFetchTime = DateTime.now();
          print('IP定位成功: ${_cachedLocation!.country}, ${_cachedLocation!.city}');
          return _cachedLocation;
        } else {
          print('IP定位失败: ${data['message']}');
          return null;
        }
      } else {
        print('IP定位请求失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('IP定位异常: $e');
      return null;
    }
  }

  // 备用的IP定位服务
  Future<IPLocation?> getCurrentLocationBackup() async {
    try {
      final response = await http
          .get(Uri.parse('https://ipinfo.io/json?token='))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final locParts = (data['loc'] as String).split(',');
        if (locParts.length == 2) {
          return IPLocation(
            ip: data['ip'] ?? '',
            country: data['country'] ?? '',
            countryCode: data['country'] ?? '',
            region: data['region'] ?? '',
            city: data['city'] ?? '',
            latitude: double.tryParse(locParts[0]) ?? 0.0,
            longitude: double.tryParse(locParts[1]) ?? 0.0,
          );
        }
      }
      return null;
    } catch (e) {
      print('备用IP定位服务异常: $e');
      return null;
    }
  }

  // 清除缓存
  void clearCache() {
    _cachedLocation = null;
    _lastFetchTime = null;
  }
}
