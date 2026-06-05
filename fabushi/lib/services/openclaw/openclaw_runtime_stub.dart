enum OpenClawRuntimeState {
  unsupported,
  notBundled,
  stopped,
  starting,
  running,
  failed,
}

class OpenClawRuntimeStatus {
  final OpenClawRuntimeState state;
  final String message;
  final int? port;
  final String? platformKey;
  final String? runtimePath;
  final DateTime checkedAt;

  const OpenClawRuntimeStatus({
    required this.state,
    required this.message,
    this.port,
    this.platformKey,
    this.runtimePath,
    required this.checkedAt,
  });

  bool get isHealthy => state == OpenClawRuntimeState.running;

  String get label {
    switch (state) {
      case OpenClawRuntimeState.unsupported:
        return '不支持';
      case OpenClawRuntimeState.notBundled:
        return '未内置';
      case OpenClawRuntimeState.stopped:
        return '未启动';
      case OpenClawRuntimeState.starting:
        return '启动中';
      case OpenClawRuntimeState.running:
        return '运行中';
      case OpenClawRuntimeState.failed:
        return '异常';
    }
  }
}

class OpenClawGatewayTarget {
  final Uri baseUri;
  final String token;
  final String model;
  final String? modelOverride;

  const OpenClawGatewayTarget({
    required this.baseUri,
    required this.token,
    required this.model,
    this.modelOverride,
  });
}

class OpenClawRuntime {
  OpenClawRuntime._();

  static final OpenClawRuntime instance = OpenClawRuntime._();

  Future<OpenClawRuntimeStatus> getStatus({bool probe = true}) async {
    return OpenClawRuntimeStatus(
      state: OpenClawRuntimeState.unsupported,
      message: '当前平台不支持内置 OpenClaw Gateway',
      checkedAt: DateTime.now(),
    );
  }

  Future<OpenClawGatewayTarget> ensureStarted({
    String? authToken,
    String? username,
    bool isMember = false,
  }) async {
    throw StateError('当前平台不支持内置 OpenClaw Gateway');
  }

  Future<OpenClawRuntimeStatus> restart() => getStatus();

  Future<void> stop() async {}
}
