import 'dart:convert';

import '../../models/mini_app_host_spec_generated.dart';

class MiniAppHostPolicyDecision {
  const MiniAppHostPolicyDecision({
    required this.allowed,
    required this.status,
    required this.method,
    required this.message,
    this.permission,
    this.capability,
  });

  final bool allowed;
  final String status;
  final String method;
  final String message;
  final String? permission;
  final String? capability;

  String get errorCode {
    switch (status) {
      case 'unknownMethod':
        return 'unknown_method';
      case 'unknownCapability':
        return 'unknown_capability';
      case 'unsupportedPlatform':
        return 'unsupported_platform';
      case 'trustRequired':
        return 'permission_denied';
      case 'denied':
        return 'permission_denied';
      default:
        return 'host_policy_denied';
    }
  }

  Map<String, dynamic> toJson() => {
    'allowed': allowed,
    'status': status,
    'method': method,
    'message': message,
    if (permission != null) 'permission': permission,
    if (capability != null) 'capability': capability,
  };
}

class MiniAppHostPolicy {
  MiniAppHostPolicy._();

  static Map<String, dynamic>? _decodedSpec;
  static Map<String, Map<String, dynamic>>? _capabilityIndex;
  static Map<String, Map<String, dynamic>>? _methodIndex;

  static Map<String, dynamic> get spec {
    final existing = _decodedSpec;
    if (existing != null) return existing;
    return _decodedSpec = Map<String, dynamic>.from(
      jsonDecode(miniAppHostSpecJson) as Map,
    );
  }

  static Map<String, Map<String, dynamic>> get capabilityIndex {
    final existing = _capabilityIndex;
    if (existing != null) return existing;
    final raw = spec['capabilities'] as List? ?? const [];
    return _capabilityIndex = {
      for (final item in raw.whereType<Map>())
        item['id'].toString(): Map<String, dynamic>.from(item),
    };
  }

  static Map<String, Map<String, dynamic>> get methodIndex {
    final existing = _methodIndex;
    if (existing != null) return existing;
    final raw = spec['methods'] as List? ?? const [];
    return _methodIndex = {
      for (final item in raw.whereType<Map>())
        item['method'].toString(): Map<String, dynamic>.from(item),
    };
  }

  static Set<String> declaredPermissions(Iterable<String> permissions) => {
    'app.context',
    'bot.chat',
    ...permissions
        .map((permission) => permission.trim())
        .where((permission) => permission.isNotEmpty),
  };

  static MiniAppHostPolicyDecision evaluateMethod({
    required String method,
    required Set<String> declaredPermissions,
    required String platform,
    required bool desktopNative,
    required bool nativeIo,
    required bool trustedOfficial,
  }) {
    final normalizedMethod = method.trim();
    final hostMethod = methodIndex[normalizedMethod];
    if (hostMethod == null) {
      return MiniAppHostPolicyDecision(
        allowed: false,
        status: 'unknownMethod',
        method: normalizedMethod,
        message: '未知小程序能力：$normalizedMethod',
      );
    }
    final permission = hostMethod['permission']?.toString() ?? '';
    final capability = capabilityIndex[permission];
    if (capability == null) {
      return MiniAppHostPolicyDecision(
        allowed: false,
        status: 'unknownCapability',
        method: normalizedMethod,
        permission: permission,
        message: '宿主缺少 capability 定义：$permission',
      );
    }

    final status = _statusForCapability(
      capability,
      declaredPermissions: declaredPermissions,
      desktopNative: desktopNative,
      nativeIo: nativeIo,
      trustedOfficial: trustedOfficial,
    );
    final id = capability['id']?.toString() ?? permission;
    return MiniAppHostPolicyDecision(
      allowed: status == 'granted',
      status: status,
      method: normalizedMethod,
      permission: permission,
      capability: id,
      message: _messageForStatus(status, capabilityId: id, platform: platform),
    );
  }

  static List<String> grantedCapabilityIds({
    required Set<String> declaredPermissions,
    required bool desktopNative,
    required bool nativeIo,
    required bool trustedOfficial,
  }) {
    final granted = <String>[];
    for (final capability in capabilityIndex.values) {
      final status = _statusForCapability(
        capability,
        declaredPermissions: declaredPermissions,
        desktopNative: desktopNative,
        nativeIo: nativeIo,
        trustedOfficial: trustedOfficial,
      );
      if (status == 'granted') {
        granted.add(capability['id'].toString());
      }
    }
    return granted..sort();
  }

  static Map<String, Map<String, dynamic>> capabilityDefinitions({
    required Set<String> declaredPermissions,
    required String platform,
    required bool desktopNative,
    required bool nativeIo,
    required bool trustedOfficial,
  }) {
    return {
      for (final entry in capabilityIndex.entries)
        entry.key: _runtimeCapability(
          entry.value,
          declaredPermissions: declaredPermissions,
          platform: platform,
          desktopNative: desktopNative,
          nativeIo: nativeIo,
          trustedOfficial: trustedOfficial,
        ),
    };
  }

  static Map<String, dynamic> requestCapabilities({
    required List<Object?> requested,
    required Set<String> declaredPermissions,
    required String platform,
    required bool desktopNative,
    required bool nativeIo,
    required bool trustedOfficial,
  }) {
    final ids =
        requested
            .map((item) {
              if (item is Map) return item['id']?.toString().trim() ?? '';
              return item?.toString().trim() ?? '';
            })
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return {
      'capabilities': [
        for (final id in ids)
          if (capabilityIndex[id] == null)
            {
              'id': id,
              'granted': false,
              'available': false,
              'platform': platform,
              'status': 'unknown',
            }
          else
            _runtimeCapability(
              capabilityIndex[id]!,
              declaredPermissions: declaredPermissions,
              platform: platform,
              desktopNative: desktopNative,
              nativeIo: nativeIo,
              trustedOfficial: trustedOfficial,
            ),
      ],
    };
  }

  static Map<String, dynamic> hostApiSpec({
    required Set<String> declaredPermissions,
    required String platform,
    required bool desktopNative,
    required bool nativeIo,
    required bool trustedOfficial,
  }) {
    final runtimeCapabilities = capabilityDefinitions(
      declaredPermissions: declaredPermissions,
      platform: platform,
      desktopNative: desktopNative,
      nativeIo: nativeIo,
      trustedOfficial: trustedOfficial,
    ).values.toList();
    return {
      ...spec,
      'hostApiVersion': miniAppHostApiVersion,
      'hostSdkVersion': miniAppHostSdkVersion,
      'platform': platform,
      'capabilities': runtimeCapabilities,
      'nativeCapabilities': [
        for (final capability in runtimeCapabilities)
          if (capability['native'] == true) capability,
      ],
    };
  }

  static Map<String, dynamic> _runtimeCapability(
    Map<String, dynamic> capability, {
    required Set<String> declaredPermissions,
    required String platform,
    required bool desktopNative,
    required bool nativeIo,
    required bool trustedOfficial,
  }) {
    final status = _statusForCapability(
      capability,
      declaredPermissions: declaredPermissions,
      desktopNative: desktopNative,
      nativeIo: nativeIo,
      trustedOfficial: trustedOfficial,
    );
    return {
      ...capability,
      'platform': platform,
      'available': _isAvailable(
        capability,
        desktopNative: desktopNative,
        nativeIo: nativeIo,
      ),
      'granted': status == 'granted',
      'status': status,
    };
  }

  static String _statusForCapability(
    Map<String, dynamic> capability, {
    required Set<String> declaredPermissions,
    required bool desktopNative,
    required bool nativeIo,
    required bool trustedOfficial,
  }) {
    final id = capability['id']?.toString() ?? '';
    if (!declaredPermissions.contains(id)) return 'denied';
    if (!_isAvailable(
      capability,
      desktopNative: desktopNative,
      nativeIo: nativeIo,
    )) {
      return 'unsupportedPlatform';
    }
    if (capability['trust'] == 'trustedOfficial' && !trustedOfficial) {
      return 'trustRequired';
    }
    return 'granted';
  }

  static bool _isAvailable(
    Map<String, dynamic> capability, {
    required bool desktopNative,
    required bool nativeIo,
  }) {
    switch (capability['availability']) {
      case 'nativeIo':
        return nativeIo;
      case 'desktopNative':
        return desktopNative;
      case 'always':
      default:
        return true;
    }
  }

  static String _messageForStatus(
    String status, {
    required String capabilityId,
    required String platform,
  }) {
    switch (status) {
      case 'granted':
        return 'granted';
      case 'denied':
        return '小程序未声明或未获准使用 $capabilityId';
      case 'unsupportedPlatform':
        return '$capabilityId 在当前平台 $platform 不可用';
      case 'trustRequired':
        return '$capabilityId 只允许受信官方小程序调用';
      default:
        return '小程序能力策略拒绝调用 $capabilityId';
    }
  }
}
