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
  final Map<String, dynamic>? desktopToolsStatus;
  final DateTime checkedAt;

  const OpenClawRuntimeStatus({
    required this.state,
    required this.message,
    this.port,
    this.platformKey,
    this.runtimePath,
    this.desktopToolsStatus,
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
  final Uri? desktopToolsUri;
  final String? desktopToolsToken;
  final Map<String, dynamic>? desktopToolsStatus;

  const OpenClawGatewayTarget({
    required this.baseUri,
    required this.token,
    required this.model,
    this.modelOverride,
    this.desktopToolsUri,
    this.desktopToolsToken,
    this.desktopToolsStatus,
  });
}

class OpenClawCliResult {
  final List<String> args;
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;

  const OpenClawCliResult({
    required this.args,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.timedOut = false,
  });

  bool get succeeded => exitCode == 0 && !timedOut;

  String get command => 'openclaw ${args.join(' ')}';

  String get combinedOutput => [
    if (stdout.trim().isNotEmpty) stdout.trimRight(),
    if (stderr.trim().isNotEmpty) stderr.trimRight(),
  ].join('\n');
}

class OpenClawRuntimeException implements Exception {
  final String message;

  const OpenClawRuntimeException(this.message);

  @override
  String toString() => message;
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
    throw const OpenClawRuntimeException('当前平台不支持内置 OpenClaw Gateway');
  }

  Future<OpenClawRuntimeStatus> restart() => getStatus();

  Future<void> stop() async {}

  Future<OpenClawCliResult> createMobilePairingCode({
    bool remote = true,
  }) async {
    throw StateError('当前平台不支持内置 OpenClaw Gateway');
  }

  Future<OpenClawCliResult> loginWeChat() async {
    throw StateError('当前平台不支持内置 OpenClaw Gateway');
  }

  Future<OpenClawCliResult> inspectChannels() async {
    throw StateError('当前平台不支持内置 OpenClaw Gateway');
  }

  Future<OpenClawCliResult> installWeChatPlugin() async {
    throw StateError('当前平台不支持内置 OpenClaw Gateway');
  }

  Future<OpenClawCliResult> runCli(
    List<String> args, {
    Duration timeout = const Duration(seconds: 45),
    bool ensureGateway = true,
  }) async {
    throw StateError('当前平台不支持内置 OpenClaw Gateway');
  }

  Map<String, dynamic> buildEmbeddedConfigForTest({
    required Object stateRoot,
    required int port,
    required String token,
    required String backendDeepSeekModel,
    required String deepSeekProxyBaseUrl,
    String remoteGatewayUrl = '',
    List<String> pluginLoadPaths = const [],
    bool hasWeChatPlugin = false,
  }) {
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> mergeEmbeddedConfigForTest(
    Object configPath,
    Map<String, dynamic> defaults,
  ) async {
    return defaults;
  }

  Map<String, String> buildOpenClawEnvironmentForTest({
    required Object runtimeDir,
    required Object stateRoot,
    required Object configPath,
    required int port,
    required String token,
  }) {
    return <String, String>{};
  }
}
