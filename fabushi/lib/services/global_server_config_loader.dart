import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'global_country_servers.dart';

/// 全球服务器配置加载器
class GlobalServerConfigLoader {
  static Map<String, List<String>>? _cachedConfig;

  /// 加载全球服务器配置
  Future<Map<String, List<String>>> loadConfig() async {
    if (_cachedConfig != null) {
      return _cachedConfig!;
    }

    // 直接使用内置配置
    final config = _getBuiltInConfig();
    _cachedConfig = config;
    return config;
  }

  /// 解析JavaScript配置对象
  static Map<String, List<String>> _parseJavaScriptConfig(dynamic jsObject) {
    final Map<String, List<String>> result = {};

    try {
      // 简化的JavaScript对象解析
      if (jsObject != null) {
        // 尝试直接转换为Map
        if (jsObject is Map) {
          jsObject.forEach((key, value) {
            if (value is List) {
              result[key.toString()] = value.cast<String>().toList();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ 解析JavaScript配置失败: $e');
    }

    return result;
  }

  /// 获取内置配置
  static Map<String, List<String>> _getBuiltInConfig() {
    debugPrint('📋 使用内置全球服务器配置');
    return GLOBAL_COUNTRY_SERVERS;
  }

  /// 从本地文件读取配置
  static Future<Map<String, List<String>>> loadFromLocalFile(String filePath) async {
    try {
      debugPrint('📁 尝试从本地文件加载配置: $filePath');
      return {};
    } catch (e) {
      debugPrint('⚠️ 从本地文件加载配置失败: $e');
      return _getBuiltInConfig();
    }
  }
}
