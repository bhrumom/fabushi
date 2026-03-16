import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/painting.dart';

/// 内存管理器
/// 
/// 负责监控和管理应用内存使用，防止 OOM 导致应用被系统杀死。
/// 
/// 核心功能：
/// 1. 定期检查内存使用情况
/// 2. LRU 策略管理缓存
/// 3. 响应系统内存警告
/// 4. 主动释放不必要的内存
class MemoryManager {
  static MemoryManager? _instance;
  static MemoryManager get instance {
    _instance ??= MemoryManager._();
    return _instance!;
  }
  
  MemoryManager._();
  
  // 配置常量
  static const int maxCacheMemoryMB = 50; // 最大缓存 50MB
  static const int cleanupIntervalSeconds = 60; // 每60秒检查一次
  static const int maxCacheItems = 10; // 最大缓存条目数
  
  // 定期清理定时器
  Timer? _cleanupTimer;
  
  // 内存警告 MethodChannel
  static const _memoryChannel = MethodChannel('com.ombhrum.fabushi/memory');
  
  // 可清理的缓存注册表
  final List<ClearableCache> _registeredCaches = [];
  
  // 记录最后一次警告时间
  DateTime? _lastWarningTime;
  
  bool _isInitialized = false;

  /// 初始化内存管理器
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // 设置系统内存警告监听
    _memoryChannel.setMethodCallHandler(_handleMemoryMethodCall);
    
    // 启动定期清理
    _startPeriodicCleanup();
    
    _isInitialized = true;
    debugPrint('✅ MemoryManager 已初始化');
  }
  
  /// 处理来自原生层的内存警告
  Future<dynamic> _handleMemoryMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onLowMemory':
        final level = call.arguments as int?;
        debugPrint('⚠️ 收到系统内存警告: level=$level');
        await handleLowMemoryWarning();
        break;
      case 'warning':
        debugPrint('⚠️ 收到 iOS 内存警告');
        await handleLowMemoryWarning();
        break;
    }
  }
  
  /// 检查并清理缓存（如果需要）
  Future<void> trimCacheIfNeeded() async {
    int totalCacheSize = 0;
    
    for (final cache in _registeredCaches) {
      totalCacheSize += cache.currentSizeBytes;
    }
    
    final totalCacheMB = totalCacheSize / (1024 * 1024);
    
    if (totalCacheMB > maxCacheMemoryMB) {
      debugPrint('🧹 [MemoryManager] 缓存超出限制 (${totalCacheMB.toStringAsFixed(1)}MB > ${maxCacheMemoryMB}MB)，开始清理...');
      
      // 按优先级排序，优先清理低优先级缓存
      final sortedCaches = List<ClearableCache>.from(_registeredCaches)
        ..sort((a, b) => a.priority.compareTo(b.priority));
      
      for (final cache in sortedCaches) {
        if (totalCacheSize <= maxCacheMemoryMB * 1024 * 1024) break;
        
        final before = cache.currentSizeBytes;
        await cache.trimToSize(cache.currentSizeBytes ~/ 2); // 减半
        final after = cache.currentSizeBytes;
        
        totalCacheSize -= (before - after);
        debugPrint('  🗑️ [MemoryManager] ${cache.cacheName}: ${(before / 1024).toStringAsFixed(0)}KB -> ${(after / 1024).toStringAsFixed(0)}KB');
      }
    }
  }
  
  /// 处理系统内存警告 - 紧急释放内存
  Future<void> handleLowMemoryWarning() async {
    debugPrint('🚨 [MemoryManager] 收到系统内存警告，启动紧急清理程序...');
    _lastWarningTime = DateTime.now();
    
    // 1. 清理 Flutter 框架层面的图片缓存
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      debugPrint('✅ [MemoryManager] 已清理 Flutter 图片缓存');
    } catch (e) {
      debugPrint('⚠️ [MemoryManager] 清理图片缓存异常: $e');
    }

    // 2. 清理所有已注册的业务缓存（包括 3D 模型 Uint8List）
    await _clearAllRegisteredCaches();
    
    // 3. 保存状态（在可能被杀死前）
    await _saveStateBeforePossibleKill();
    
    debugPrint('🚨 [MemoryManager] 紧急内存清理完成');
  }

  /// 清理所有已注册的缓存
  Future<void> _clearAllRegisteredCaches() async {
    debugPrint('🚨 [MemoryManager] 开始清理所有注册的业务缓存...');
    for (final cache in _registeredCaches) {
      try {
        await cache.clearAll();
        debugPrint('  🗑️ [MemoryManager] 已清空: ${cache.cacheName}');
      } catch (e) {
        debugPrint('  ❌ [MemoryManager] 清空失败 ${cache.cacheName}: $e');
      }
    }
  }
  
  /// 保存状态（在可能被杀死前）
  Future<void> _saveStateBeforePossibleKill() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lastMemoryWarningTime', DateTime.now().millisecondsSinceEpoch);
      debugPrint('💾 已保存内存警告时间戳');
    } catch (e) {
      debugPrint('❌ 保存状态失败: $e');
    }
  }
  
  /// 注册可清理缓存
  void registerCache(ClearableCache cache) {
    if (!_registeredCaches.contains(cache)) {
      _registeredCaches.add(cache);
      debugPrint('📦 [MemoryManager] 已注册缓存: ${cache.cacheName}');
    }
  }

  /// 启动定期清理
  void _startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: cleanupIntervalSeconds), (timer) {
      trimCacheIfNeeded();
    });
  }
  
  /// 停止内存管理器
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _registeredCaches.clear();
    _isInitialized = false;
  }
}

/// 可清理缓存接口
abstract class ClearableCache {
  /// 缓存名称（用于日志）
  String get cacheName;
  
  /// 当前缓存大小（字节）
  int get currentSizeBytes;
  
  /// 清理优先级（数字越小优先级越低，越先被清理）
  int get priority;
  
  /// 清理到指定大小
  Future<void> trimToSize(int targetBytes);
  
  /// 清空所有缓存
  Future<void> clearAll();
}

/// 通用 LRU 缓存包装器
class LRUCacheWrapper<K, V> implements ClearableCache {
  final String _name;
  final int _maxItems;
  final int Function(V value) _sizeCalculator;
  final int _priorityLevel;
  
  final Map<K, V> _cache = {};
  final Map<K, DateTime> _accessTime = {};
  
  LRUCacheWrapper({
    required String name,
    required int maxItems,
    required int Function(V value) sizeCalculator,
    int priority = 5,
  }) : _name = name,
       _maxItems = maxItems,
       _sizeCalculator = sizeCalculator,
       _priorityLevel = priority;
  
  @override
  String get cacheName => _name;
  
  @override
  int get priority => _priorityLevel;
  
  @override
  int get currentSizeBytes {
    int total = 0;
    for (final value in _cache.values) {
      total += _sizeCalculator(value);
    }
    return total;
  }
  
  /// 获取缓存值
  V? get(K key) {
    if (_cache.containsKey(key)) {
      _accessTime[key] = DateTime.now();
      return _cache[key];
    }
    return null;
  }
  
  /// 设置缓存值
  void set(K key, V value) {
    _cache[key] = value;
    _accessTime[key] = DateTime.now();
    _trimIfNeeded();
  }
  
  /// 检查是否存在
  bool containsKey(K key) => _cache.containsKey(key);
  
  /// 删除指定键
  void remove(K key) {
    _cache.remove(key);
    _accessTime.remove(key);
  }
  
  /// 内部 LRU 清理
  void _trimIfNeeded() {
    while (_cache.length > _maxItems) {
      // 找到最久未访问的条目
      K? oldest;
      DateTime? oldestTime;
      
      for (final entry in _accessTime.entries) {
        if (oldestTime == null || entry.value.isBefore(oldestTime)) {
          oldest = entry.key;
          oldestTime = entry.value;
        }
      }
      
      if (oldest != null) {
        _cache.remove(oldest);
        _accessTime.remove(oldest);
      } else {
        break;
      }
    }
  }
  
  @override
  Future<void> trimToSize(int targetBytes) async {
    while (currentSizeBytes > targetBytes && _cache.isNotEmpty) {
      // 移除最老的条目
      K? oldest;
      DateTime? oldestTime;
      
      for (final entry in _accessTime.entries) {
        if (oldestTime == null || entry.value.isBefore(oldestTime)) {
          oldest = entry.key;
          oldestTime = entry.value;
        }
      }
      
      if (oldest != null) {
        _cache.remove(oldest);
        _accessTime.remove(oldest);
      } else {
        break;
      }
    }
  }
  
  @override
  Future<void> clearAll() async {
    _cache.clear();
    _accessTime.clear();
  }
}
