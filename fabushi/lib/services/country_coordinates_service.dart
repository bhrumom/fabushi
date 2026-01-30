import 'dart:convert';
import 'package:flutter/services.dart';

class CountryCoordinate {
  final String countryName;
  final String capitalName;
  final double latitude;
  final double longitude;
  final String? countryCode;
  final String continentName;

  CountryCoordinate({
    required this.countryName,
    required this.capitalName,
    required this.latitude,
    required this.longitude,
    this.countryCode,
    required this.continentName,
  });
}

class CountryCoordinatesService {
  static final CountryCoordinatesService _instance = CountryCoordinatesService._internal();
  factory CountryCoordinatesService() => _instance;
  CountryCoordinatesService._internal();

  List<CountryCoordinate> _coordinates = [];
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final csvData = await rootBundle.loadString('assets/data/concap.csv');
      final lines = csvData.split('\n').skip(1); // Skip header

      for (var line in lines) {
        if (line.trim().isEmpty) continue;

        final parts = line.split(',');
        if (parts.length >= 6) {
          final lat = double.tryParse(parts[2].trim());
          final lng = double.tryParse(parts[3].trim());

          if (lat != null && lng != null && lat != 0 && lng != 0) {
            _coordinates.add(
              CountryCoordinate(
                countryName: parts[0].trim(),
                capitalName: parts[1].trim(),
                latitude: lat,
                longitude: lng,
                countryCode: parts[4].trim() == 'NULL' ? null : parts[4].trim(),
                continentName: parts[5].trim(),
              ),
            );
          }
        }
      }

      _isInitialized = true;
    } catch (e) {
      print('加载国家坐标失败: $e');
    }
  }

  List<CountryCoordinate> getAllCoordinates() => _coordinates;

  CountryCoordinate? getByCountryCode(String code) {
    return _coordinates.where((c) => c.countryCode == code).firstOrNull;
  }

  CountryCoordinate? getByCoordinates(double lat, double lng, {double tolerance = 5.0}) {
    // 查找最接近给定坐标的国家（容差范围内）
    for (var coord in _coordinates) {
      final latDiff = (coord.latitude - lat).abs();
      final lngDiff = (coord.longitude - lng).abs();
      if (latDiff < tolerance && lngDiff < tolerance) {
        return coord;
      }
    }
    return null;
  }

  List<CountryCoordinate> getByContinent(String continent) {
    return _coordinates.where((c) => c.continentName == continent).toList();
  }

  CountryCoordinate getRandomCountry() {
    return _coordinates[DateTime.now().millisecondsSinceEpoch % _coordinates.length];
  }
}
