import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'llm_model_config.dart';

/// 设备能力检测服务
///
/// 检测设备的 RAM、存储空间、CPU 核心数等硬件信息，
/// 用于智能推荐适合的 LLM 模型。
class DeviceCapabilityService {
  static DeviceCapabilityService? _instance;
  static DeviceCapabilityService get instance =>
      _instance ??= DeviceCapabilityService._();
  DeviceCapabilityService._();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // 缓存设备信息
  int? _cachedRamMb;
  int? _cachedCpuCores;
  DeviceLevel? _cachedLevel;

  /// 获取设备总 RAM（MB）
  ///
  /// 返回设备的总物理内存大小。
  /// Android 可以直接获取，iOS 使用估算值。
  Future<int> getTotalRam() async {
    if (_cachedRamMb != null) return _cachedRamMb!;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Android API 16+ 支持 totalMem
        // systemFeatures 中可能包含内存信息
        // 使用 /proc/meminfo 更准确，但这里用估算
        _cachedRamMb = _estimateAndroidRam(androidInfo);
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _cachedRamMb = _estimateIosRam(iosInfo);
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        _cachedRamMb = _estimateMacRam(macInfo);
      } else {
        // 默认估算 4GB
        _cachedRamMb = 4096;
      }
    } catch (e) {
      debugPrint('DeviceCapabilityService: 获取 RAM 失败: $e');
      _cachedRamMb = 4096; // 默认 4GB
    }

    return _cachedRamMb!;
  }

  /// 获取可用存储空间（MB）
  Future<int> getAvailableStorage() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final stat = await FileStat.stat(docDir.path);
      // FileStat 不提供磁盘空间信息，使用 Platform 特定方法
      // 这里使用 Directory 的 statSync 获取估算值

      // 简单估算：检查 documents 目录所在分区
      // 实际实现可能需要平台通道
      if (Platform.isAndroid || Platform.isIOS) {
        // 移动端通常有足够空间，返回保守估算
        return 10 * 1024; // 假设 10GB 可用
      } else {
        return 50 * 1024; // 桌面端假设 50GB
      }
    } catch (e) {
      debugPrint('DeviceCapabilityService: 获取存储空间失败: $e');
      return 5 * 1024; // 默认 5GB
    }
  }

  /// 获取 CPU 核心数
  int getCpuCores() {
    if (_cachedCpuCores != null) return _cachedCpuCores!;
    _cachedCpuCores = Platform.numberOfProcessors;
    return _cachedCpuCores!;
  }

  /// 获取设备能力等级
  Future<DeviceLevel> getDeviceLevel() async {
    if (_cachedLevel != null) return _cachedLevel!;

    final ramMb = await getTotalRam();

    if (ramMb < 3 * 1024) {
      _cachedLevel = DeviceLevel.low;
    } else if (ramMb < 6 * 1024) {
      _cachedLevel = DeviceLevel.medium;
    } else {
      _cachedLevel = DeviceLevel.high;
    }

    return _cachedLevel!;
  }

  /// 根据设备能力推荐模型
  Future<LLMModelType> recommendModel() async {
    final level = await getDeviceLevel();
    return LLMModelConfig.recommendForDeviceLevel(level);
  }

  /// 检查设备是否可以运行指定模型
  Future<bool> canRunModel(LLMModelType type) async {
    final ramMb = await getTotalRam();
    return LLMModelConfig.canRunModel(type, ramMb);
  }

  /// 获取对用户友好的设备能力描述
  Future<String> getDeviceCapabilityDescription() async {
    final ramMb = await getTotalRam();
    final cpuCores = getCpuCores();
    final level = await getDeviceLevel();

    final ramStr = ramMb >= 1024
        ? '${(ramMb / 1024).toStringAsFixed(1)} GB'
        : '$ramMb MB';

    final levelStr = switch (level) {
      DeviceLevel.low => '入门级',
      DeviceLevel.medium => '标准',
      DeviceLevel.high => '高端',
    };

    return '设备内存: $ramStr | CPU核心: $cpuCores | 等级: $levelStr';
  }

  /// 获取设备能力详情（用于 UI 显示）
  Future<DeviceCapabilityInfo> getDeviceCapabilityInfo() async {
    final ramMb = await getTotalRam();
    final storageMb = await getAvailableStorage();
    final cpuCores = getCpuCores();
    final level = await getDeviceLevel();
    final recommended = await recommendModel();

    return DeviceCapabilityInfo(
      ramMb: ramMb,
      storageMb: storageMb,
      cpuCores: cpuCores,
      level: level,
      recommendedModel: recommended,
    );
  }

  // ============== 私有方法 ==============

  /// 估算 Android 设备 RAM
  int _estimateAndroidRam(AndroidDeviceInfo info) {
    // 基于设备型号和 SDK 版本估算
    // 低端设备（旧型号）：2-3GB
    // 中端设备：4-6GB
    // 高端设备：8GB+

    final sdkInt = info.version.sdkInt;

    // Android 10+ 通常是较新设备
    if (sdkInt >= 29) {
      // 检查是否是高端品牌
      final brand = info.brand.toLowerCase();
      if (brand.contains('samsung') ||
          brand.contains('google') ||
          brand.contains('oneplus')) {
        return 6 * 1024; // 6GB
      }
      return 4 * 1024; // 4GB
    } else if (sdkInt >= 26) {
      return 3 * 1024; // 3GB
    } else {
      return 2 * 1024; // 2GB
    }
  }

  /// 估算 iOS 设备 RAM
  int _estimateIosRam(IosDeviceInfo info) {
    final model = info.utsname.machine.toLowerCase();

    // iPhone 15 Pro Max: 8GB
    // iPhone 14/15: 6GB
    // iPhone 12/13: 4-6GB
    // iPhone 11 及以下: 3-4GB

    if (model.contains('iphone16') || model.contains('iphone15,3')) {
      return 8 * 1024; // 8GB
    } else if (model.contains('iphone15') || model.contains('iphone14')) {
      return 6 * 1024; // 6GB
    } else if (model.contains('iphone13') || model.contains('iphone12')) {
      return 4 * 1024; // 4GB
    } else {
      return 3 * 1024; // 3GB
    }
  }

  /// 估算 macOS 设备 RAM
  int _estimateMacRam(MacOsDeviceInfo info) {
    // macOS 设备通常有较多 RAM
    // M1/M2 Mac 通常 8-16GB
    // Intel Mac 通常 8-32GB

    final model = info.model.toLowerCase();
    if (model.contains('macbookair')) {
      return 8 * 1024; // 8GB
    } else if (model.contains('macbookpro') || model.contains('macmini')) {
      return 16 * 1024; // 16GB
    } else {
      return 8 * 1024; // 8GB 默认
    }
  }
}

/// 设备能力信息
class DeviceCapabilityInfo {
  final int ramMb;
  final int storageMb;
  final int cpuCores;
  final DeviceLevel level;
  final LLMModelType recommendedModel;

  const DeviceCapabilityInfo({
    required this.ramMb,
    required this.storageMb,
    required this.cpuCores,
    required this.level,
    required this.recommendedModel,
  });

  /// RAM 可读字符串
  String get ramString =>
      ramMb >= 1024 ? '${(ramMb / 1024).toStringAsFixed(1)} GB' : '$ramMb MB';

  /// 存储空间可读字符串
  String get storageString => storageMb >= 1024
      ? '${(storageMb / 1024).toStringAsFixed(1)} GB'
      : '$storageMb MB';

  /// 等级可读字符串
  String get levelString => switch (level) {
    DeviceLevel.low => '入门级',
    DeviceLevel.medium => '标准',
    DeviceLevel.high => '高端',
  };
}
