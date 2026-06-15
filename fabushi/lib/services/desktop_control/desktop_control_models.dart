enum DesktopControlPermissionState { granted, denied, unknown, notApplicable }

enum DesktopControlConfirmationState { pending, approved, rejected, expired }

class DesktopControlBridgeStatus {
  final bool enabledByBuild;
  final bool supportedPlatform;
  final bool bridgeRunning;
  final String platform;
  final String message;
  final Uri? bridgeUri;
  final bool screenRecordingGranted;
  final bool accessibilityGranted;
  final ChromeConnectorStatus chrome;
  final int pendingConfirmationCount;

  const DesktopControlBridgeStatus({
    required this.enabledByBuild,
    required this.supportedPlatform,
    required this.bridgeRunning,
    required this.platform,
    required this.message,
    this.bridgeUri,
    required this.screenRecordingGranted,
    required this.accessibilityGranted,
    required this.chrome,
    this.pendingConfirmationCount = 0,
  });

  bool get desktopControlAvailable =>
      enabledByBuild && supportedPlatform && bridgeRunning;

  Map<String, dynamic> toJson() => {
    'enabledByBuild': enabledByBuild,
    'supportedPlatform': supportedPlatform,
    'bridgeRunning': bridgeRunning,
    'platform': platform,
    'message': message,
    'bridgeUri': bridgeUri?.toString(),
    'screenRecordingGranted': screenRecordingGranted,
    'accessibilityGranted': accessibilityGranted,
    'chrome': chrome.toJson(),
    'pendingConfirmationCount': pendingConfirmationCount,
  };

  factory DesktopControlBridgeStatus.fromJson(Map<String, dynamic> json) {
    final bridgeUri = json['bridgeUri']?.toString();
    return DesktopControlBridgeStatus(
      enabledByBuild: json['enabledByBuild'] == true,
      supportedPlatform: json['supportedPlatform'] == true,
      bridgeRunning: json['bridgeRunning'] == true,
      platform: (json['platform'] ?? 'unknown').toString(),
      message: (json['message'] ?? '').toString(),
      bridgeUri: bridgeUri == null || bridgeUri.isEmpty
          ? null
          : Uri.tryParse(bridgeUri),
      screenRecordingGranted: json['screenRecordingGranted'] == true,
      accessibilityGranted: json['accessibilityGranted'] == true,
      chrome: ChromeConnectorStatus.fromJson(
        Map<String, dynamic>.from(json['chrome'] as Map? ?? const {}),
      ),
      pendingConfirmationCount: _readInt(json['pendingConfirmationCount']) ?? 0,
    );
  }
}

class ChromeConnectorStatus {
  final bool connected;
  final String message;
  final String? connectorId;
  final String? extensionVersion;
  final DateTime? lastSeenAt;

  const ChromeConnectorStatus({
    required this.connected,
    required this.message,
    this.connectorId,
    this.extensionVersion,
    this.lastSeenAt,
  });

  factory ChromeConnectorStatus.disconnected([String? message]) {
    return ChromeConnectorStatus(
      connected: false,
      message: message ?? 'Chrome 连接器未连接',
    );
  }

  Map<String, dynamic> toJson() => {
    'connected': connected,
    'message': message,
    if (connectorId != null) 'connectorId': connectorId,
    if (extensionVersion != null) 'extensionVersion': extensionVersion,
    if (lastSeenAt != null) 'lastSeenAt': lastSeenAt!.toIso8601String(),
  };

  factory ChromeConnectorStatus.fromJson(Map<String, dynamic> json) {
    final rawLastSeen = json['lastSeenAt']?.toString();
    return ChromeConnectorStatus(
      connected: json['connected'] == true,
      message: (json['message'] ?? '').toString(),
      connectorId: json['connectorId']?.toString(),
      extensionVersion: json['extensionVersion']?.toString(),
      lastSeenAt: rawLastSeen == null || rawLastSeen.isEmpty
          ? null
          : DateTime.tryParse(rawLastSeen),
    );
  }
}

class DesktopControlToolRequest {
  final String id;
  final String toolName;
  final Map<String, dynamic> arguments;
  final String? confirmationId;

  const DesktopControlToolRequest({
    required this.id,
    required this.toolName,
    this.arguments = const {},
    this.confirmationId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tool': toolName,
    'arguments': arguments,
    if (confirmationId != null) 'confirmationId': confirmationId,
  };

  factory DesktopControlToolRequest.fromJson(Map<String, dynamic> json) {
    return DesktopControlToolRequest(
      id: (json['id'] ?? '').toString(),
      toolName: (json['tool'] ?? json['toolName'] ?? '').toString(),
      arguments: Map<String, dynamic>.from(
        json['arguments'] as Map? ?? const {},
      ),
      confirmationId: json['confirmationId']?.toString(),
    );
  }
}

class DesktopControlToolResult {
  final bool ok;
  final Map<String, dynamic> data;
  final String? errorCode;
  final String? message;
  final bool requiresConfirmation;
  final String? pendingConfirmationId;
  final bool recoverable;

  const DesktopControlToolResult({
    required this.ok,
    this.data = const {},
    this.errorCode,
    this.message,
    this.requiresConfirmation = false,
    this.pendingConfirmationId,
    this.recoverable = false,
  });

  factory DesktopControlToolResult.success([Map<String, dynamic>? data]) {
    return DesktopControlToolResult(ok: true, data: data ?? const {});
  }

  factory DesktopControlToolResult.failure({
    required String errorCode,
    required String message,
    bool recoverable = false,
    Map<String, dynamic>? data,
  }) {
    return DesktopControlToolResult(
      ok: false,
      errorCode: errorCode,
      message: message,
      recoverable: recoverable,
      data: data ?? const {},
    );
  }

  factory DesktopControlToolResult.confirmationRequired(
    DesktopControlPendingConfirmation pending,
  ) {
    return DesktopControlToolResult(
      ok: false,
      errorCode: 'confirmation_required',
      message: pending.summary,
      requiresConfirmation: true,
      pendingConfirmationId: pending.id,
      recoverable: true,
      data: pending.toJson(),
    );
  }

  Map<String, dynamic> toJson() => {
    'ok': ok,
    'data': data,
    if (errorCode != null) 'errorCode': errorCode,
    if (message != null) 'message': message,
    'requiresConfirmation': requiresConfirmation,
    if (pendingConfirmationId != null)
      'pendingConfirmationId': pendingConfirmationId,
    'recoverable': recoverable,
  };

  factory DesktopControlToolResult.fromJson(Map<String, dynamic> json) {
    return DesktopControlToolResult(
      ok: json['ok'] == true,
      data: Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
      errorCode: json['errorCode']?.toString(),
      message: json['message']?.toString(),
      requiresConfirmation: json['requiresConfirmation'] == true,
      pendingConfirmationId: json['pendingConfirmationId']?.toString(),
      recoverable: json['recoverable'] == true,
    );
  }
}

class DesktopControlPendingConfirmation {
  final String id;
  final String toolName;
  final Map<String, dynamic> arguments;
  final String summary;
  final DesktopControlConfirmationState state;
  final DateTime createdAt;
  final DateTime expiresAt;

  const DesktopControlPendingConfirmation({
    required this.id,
    required this.toolName,
    required this.arguments,
    required this.summary,
    required this.state,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isActive =>
      state == DesktopControlConfirmationState.pending &&
      DateTime.now().isBefore(expiresAt);

  DesktopControlPendingConfirmation copyWith({
    DesktopControlConfirmationState? state,
  }) {
    return DesktopControlPendingConfirmation(
      id: id,
      toolName: toolName,
      arguments: arguments,
      summary: summary,
      state: state ?? this.state,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tool': toolName,
    'arguments': arguments,
    'summary': summary,
    'state': state.name,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
