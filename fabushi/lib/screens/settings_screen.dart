import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'keep_alive_guide_screen.dart';
import 'practice_privacy_screen.dart';
import '../core/constants/app_constants.dart';
import '../services/api_client.dart';
import '../services/ai_backend_policy.dart';
import '../services/app_build_info_service.dart';
import '../services/app_settings.dart';
import '../services/llm_model_config.dart';
import '../services/llm_model_manager.dart';
import '../services/device_capability_service.dart';
import '../services/desktop_control/desktop_control_bridge.dart';
import '../services/desktop_control/desktop_control_models.dart';
import '../services/diagnostic_log_service.dart';
import '../services/openclaw/openclaw_runtime.dart';
import '../services/worker_config.dart';
import '../widgets/model_selection_dialog.dart';
import '../models/auth_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _defaultTtsMuted = true;
  bool _isLoading = true;
  bool _isSubmittingFeedback = false;
  String _appVersionLabel = AppConstants.appVersion;

  // 读诵匹配阈值（百分比形式，0.0 ~ 1.0）
  double _fastMatchThreshold = 0.50;
  double _matchThreshold = 0.50;

  // AI 模型设置
  DeviceCapabilityInfo? _deviceInfo;
  LLMModelType? _selectedModel;
  Map<LLMModelType, ModelStatus>? _modelStatus;

  // 下载进度状态
  StreamSubscription<DownloadProgressEvent>? _downloadProgressSubscription;
  double _downloadProgress = 0.0;
  String _downloadStage = '';
  bool _isDownloading = false;

  // 桌面 AI / OpenClaw 设置
  String _aiBackendModeName = 'auto';
  String _openClawRemoteGatewayUrl = '';
  OpenClawRuntimeStatus? _openClawStatus;
  DesktopControlBridgeStatus? _desktopControlStatus;
  List<DesktopControlPendingConfirmation> _desktopControlPending = const [];
  bool _isRestartingOpenClaw = false;
  bool _isRunningOpenClawCli = false;
  bool _isPreparingChromeConnector = false;
  StreamSubscription<void>? _desktopControlSubscription;
  String _settingsCategory = 'system';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _subscribeToDownloadProgress();
    _subscribeToDesktopControlConfirmations();
  }

  @override
  void dispose() {
    _downloadProgressSubscription?.cancel();
    _desktopControlSubscription?.cancel();
    super.dispose();
  }

  /// 订阅下载进度流
  void _subscribeToDownloadProgress() {
    // 检查是否有正在进行的下载
    if (LLMModelManager.instance.isDownloading) {
      _isDownloading = true;
      _downloadProgress = LLMModelManager.instance.currentDownloadProgress;
      _downloadStage = LLMModelManager.instance.currentDownloadStage;
    }

    _downloadProgressSubscription = LLMModelManager
        .instance
        .downloadProgressStream
        .listen((event) {
          if (mounted) {
            setState(() {
              _isDownloading = !event.isComplete;
              _downloadProgress = event.progress;
              _downloadStage = event.stage;
            });

            // 下载完成时刷新模型状态
            if (event.isComplete) {
              _refreshModelStatus();
            }
          }
        });
  }

  void _subscribeToDesktopControlConfirmations() {
    _desktopControlSubscription = DesktopControlBridge
        .instance
        .confirmationsChanged
        .listen((_) {
          if (mounted) {
            _refreshDesktopControlStatus();
          }
        });
  }

  /// 刷新模型状态
  Future<void> _refreshModelStatus() async {
    final newStatus = await _loadSetting<Map<LLMModelType, ModelStatus>?>(
      '刷新模型状态',
      LLMModelManager.instance.getAllModelStatus(),
      _modelStatus,
      timeout: const Duration(seconds: 8),
    );
    if (newStatus == null) return;
    if (mounted) {
      setState(() {
        _modelStatus = newStatus;
      });
    }
  }

  Future<void> _loadSettings() async {
    final values = await Future.wait<dynamic>([
      _loadSetting<bool>(
        '默认静音设置',
        AppSettings.getDefaultTtsMuted(),
        _defaultTtsMuted,
      ),
      _loadSetting<double>(
        '快速匹配阈值',
        AppSettings.getFastMatchThreshold(),
        _fastMatchThreshold,
      ),
      _loadSetting<double>(
        '普通匹配阈值',
        AppSettings.getMatchThreshold(),
        _matchThreshold,
      ),
      _loadSetting<String>(
        '版本信息',
        AppBuildInfoService.instance.getVersionLabel(),
        _appVersionLabel,
      ),
      _loadSetting<String>(
        'AI 后端模式',
        AppSettings.getAiBackendModeName(),
        _aiBackendModeName,
      ),
      _loadSetting<String>(
        'OpenClaw 远程入口',
        AppSettings.getOpenClawRemoteGatewayUrl(),
        _openClawRemoteGatewayUrl,
      ),
    ]);

    if (mounted) {
      setState(() {
        _defaultTtsMuted = values[0] as bool;
        _fastMatchThreshold = values[1] as double;
        _matchThreshold = values[2] as double;
        _appVersionLabel = values[3] as String;
        _aiBackendModeName = values[4] as String;
        _openClawRemoteGatewayUrl = values[5] as String;
        _isLoading = false;
      });
    }

    unawaited(_loadModelSettings());
    unawaited(_loadDesktopRuntimeSettings(probeOpenClaw: false));
  }

  Future<void> _loadModelSettings() async {
    final values = await Future.wait<dynamic>([
      _loadSetting<DeviceCapabilityInfo?>(
        '设备能力信息',
        DeviceCapabilityService.instance.getDeviceCapabilityInfo(),
        _deviceInfo,
        timeout: const Duration(seconds: 5),
      ),
      _loadSetting<Map<LLMModelType, ModelStatus>?>(
        '模型状态',
        LLMModelManager.instance.getAllModelStatus(),
        _modelStatus,
        timeout: const Duration(seconds: 8),
      ),
      _loadSetting<String?>('已选模型', AppSettings.getSelectedModelName(), null),
    ]);

    final savedModelName = values[2] as String?;
    LLMModelType? selectedModel;
    if (savedModelName != null) {
      try {
        selectedModel = LLMModelType.values.firstWhere(
          (t) => t.name == savedModelName,
        );
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _deviceInfo = values[0] as DeviceCapabilityInfo?;
        _modelStatus = values[1] as Map<LLMModelType, ModelStatus>?;
        _selectedModel = selectedModel;
      });
    }
  }

  Future<void> _loadDesktopRuntimeSettings({
    required bool probeOpenClaw,
  }) async {
    if (!AiBackendPolicy.isDesktopNative) return;
    final values = await Future.wait<dynamic>([
      _readOpenClawStatus(probe: probeOpenClaw),
      _readDesktopControlStatus(),
      _loadSetting<List<DesktopControlPendingConfirmation>>(
        '桌面控制确认请求',
        DesktopControlBridge.instance.pendingConfirmations(),
        const [],
      ),
    ]);

    if (mounted) {
      setState(() {
        _openClawStatus = values[0] as OpenClawRuntimeStatus;
        _desktopControlStatus = values[1] as DesktopControlBridgeStatus;
        _desktopControlPending =
            values[2] as List<DesktopControlPendingConfirmation>;
      });
    }
  }

  Future<OpenClawRuntimeStatus> _readOpenClawStatus({
    required bool probe,
  }) async {
    try {
      return await OpenClawRuntime.instance
          .getStatus(probe: probe)
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('Settings: OpenClaw 状态检测失败: $error');
      return OpenClawRuntimeStatus(
        state: OpenClawRuntimeState.failed,
        message: 'OpenClaw 状态检测失败：$error',
        checkedAt: DateTime.now(),
      );
    }
  }

  Future<DesktopControlBridgeStatus> _readDesktopControlStatus({
    bool startBridge = false,
  }) async {
    try {
      final future = startBridge
          ? DesktopControlBridge.instance.ensureStarted()
          : DesktopControlBridge.instance.getStatus();
      return await future.timeout(
        startBridge ? const Duration(seconds: 15) : const Duration(seconds: 5),
      );
    } catch (error) {
      debugPrint('Settings: 桌面控制状态检测失败: $error');
      return DesktopControlBridgeStatus(
        enabledByBuild: true,
        supportedPlatform: AiBackendPolicy.isDesktopNative,
        bridgeRunning: false,
        platform: defaultTargetPlatform.name,
        message: '桌面控制状态检测失败：$error',
        screenRecordingGranted: false,
        accessibilityGranted: false,
        chrome: ChromeConnectorStatus.disconnected('Chrome 连接器状态未知'),
      );
    }
  }

  Future<T> _loadSetting<T>(
    String label,
    Future<T> future,
    T fallback, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      return await future.timeout(timeout);
    } catch (error) {
      debugPrint('Settings: $label 加载失败: $error');
      return fallback;
    }
  }

  Future<void> _setDefaultTtsMuted(bool value) async {
    setState(() => _defaultTtsMuted = value);
    await AppSettings.setDefaultTtsMuted(value);
  }

  Future<void> _setFastMatchThreshold(double value) async {
    setState(() => _fastMatchThreshold = value);
    await AppSettings.setFastMatchThreshold(value);
  }

  Future<void> _setMatchThreshold(double value) async {
    setState(() => _matchThreshold = value);
    await AppSettings.setMatchThreshold(value);
  }

  Future<void> _setAiBackendModeName(String? value) async {
    if (value == null || value.isEmpty) return;
    setState(() => _aiBackendModeName = value);
    await AppSettings.setAiBackendModeName(value);
  }

  Future<void> _editOpenClawRemoteGatewayUrl() async {
    final controller = TextEditingController(text: _openClawRemoteGatewayUrl);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('远程入口'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'wss://...',
            helperText: '移动端远程扫码需要公网 HTTPS/Tailscale Serve/Funnel 入口',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await AppSettings.setOpenClawRemoteGatewayUrl(value);
    if (!mounted) return;
    setState(() => _openClawRemoteGatewayUrl = value.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已保存远程入口，重启本机 AI 后生效'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _runOpenClawCliAction(
    String label,
    Future<OpenClawCliResult> Function() action,
  ) async {
    if (!AiBackendPolicy.isDesktopNative || _isRunningOpenClawCli) return;
    setState(() => _isRunningOpenClawCli = true);
    OpenClawCliResult? result;
    Object? error;
    try {
      result = await action();
    } catch (err) {
      error = err;
      debugPrint('Settings: $label 失败: $err');
    }
    if (!mounted) return;
    setState(() => _isRunningOpenClawCli = false);
    if (result != null) {
      await _showOpenClawCliResult(label, result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label 失败：$error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    unawaited(_loadDesktopRuntimeSettings(probeOpenClaw: true));
  }

  Future<void> _showOpenClawCliResult(
    String title,
    OpenClawCliResult result,
  ) async {
    final output = [
      result.command,
      'exitCode=${result.exitCode}${result.timedOut ? ' · timed out' : ''}',
      if (result.combinedOutput.trim().isNotEmpty) '',
      if (result.combinedOutput.trim().isNotEmpty) result.combinedOutput,
    ].join('\n');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: SelectableText(
              output,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: output));
              Navigator.of(context).pop();
            },
            child: const Text('复制'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _createOpenClawMobilePairingCode() async {
    if (_openClawRemoteGatewayUrl.trim().isEmpty) {
      await _editOpenClawRemoteGatewayUrl();
      if (_openClawRemoteGatewayUrl.trim().isEmpty) return;
    }
    await _runOpenClawCliAction(
      '移动端配对码',
      () => OpenClawRuntime.instance.createMobilePairingCode(remote: true),
    );
  }

  Future<void> _installOpenClawWeChatPlugin() {
    return _runOpenClawCliAction(
      '安装微信插件',
      OpenClawRuntime.instance.installWeChatPlugin,
    );
  }

  Future<void> _loginOpenClawWeChat() {
    return _runOpenClawCliAction(
      '微信扫码登录',
      OpenClawRuntime.instance.loginWeChat,
    );
  }

  Future<void> _inspectOpenClawChannels() {
    return _runOpenClawCliAction(
      'OpenClaw 渠道状态',
      OpenClawRuntime.instance.inspectChannels,
    );
  }

  Future<void> _requestDesktopPermission({
    required bool screenRecording,
  }) async {
    final result = screenRecording
        ? await DesktopControlBridge.instance.requestScreenRecordingPermission()
        : await DesktopControlBridge.instance.requestAccessibilityPermission();
    await _refreshDesktopControlStatus(startBridge: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? '已打开系统权限请求'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _refreshOpenClawStatus() async {
    if (!AiBackendPolicy.isDesktopNative) return;
    final status = await _readOpenClawStatus(probe: true);
    if (mounted) {
      setState(() => _openClawStatus = status);
    }
    await _refreshDesktopControlStatus();
  }

  Future<void> _refreshDesktopControlStatus({bool startBridge = false}) async {
    if (!AiBackendPolicy.isDesktopNative) return;
    final status = await _readDesktopControlStatus(startBridge: startBridge);
    final pending = await _loadSetting<List<DesktopControlPendingConfirmation>>(
      '桌面控制确认请求',
      DesktopControlBridge.instance.pendingConfirmations(),
      _desktopControlPending,
    );
    if (mounted) {
      setState(() {
        _desktopControlStatus = status;
        _desktopControlPending = pending;
      });
    }
  }

  Future<void> _restartOpenClawRuntime() async {
    if (!AiBackendPolicy.isDesktopNative || _isRestartingOpenClaw) return;
    setState(() => _isRestartingOpenClaw = true);
    final status = await _restartOpenClawRuntimeSafely();
    if (!mounted) return;
    setState(() {
      _openClawStatus = status;
      _isRestartingOpenClaw = false;
    });
    unawaited(_refreshDesktopControlStatus());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(status.isHealthy ? '本机 OpenClaw 已启动' : status.message),
        backgroundColor: status.isHealthy ? Colors.green : Colors.redAccent,
      ),
    );
  }

  Future<OpenClawRuntimeStatus> _restartOpenClawRuntimeSafely() async {
    try {
      return await OpenClawRuntime.instance.restart().timeout(
        const Duration(seconds: 75),
      );
    } catch (error) {
      debugPrint('Settings: OpenClaw 重启失败: $error');
      return OpenClawRuntimeStatus(
        state: OpenClawRuntimeState.failed,
        message: 'OpenClaw 重启失败：$error',
        checkedAt: DateTime.now(),
      );
    }
  }

  Future<void> _prepareChromeConnectorInstall() async {
    if (!AiBackendPolicy.isDesktopNative || _isPreparingChromeConnector) return;
    setState(() => _isPreparingChromeConnector = true);
    String? path;
    Object? installError;
    try {
      path = await DesktopControlBridge.instance
          .prepareChromeConnectorInstall()
          .timeout(const Duration(seconds: 20));
      await _refreshDesktopControlStatus();
    } catch (error) {
      debugPrint('Settings: Chrome 连接器准备失败: $error');
      installError = error;
    }
    if (!mounted) return;
    setState(() => _isPreparingChromeConnector = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          installError != null
              ? 'Chrome 连接器准备失败：$installError'
              : path == null
              ? '当前构建未启用 Chrome 连接器'
              : 'Chrome 连接器目录已打开',
        ),
        backgroundColor: installError != null
            ? Colors.redAccent
            : path == null
            ? Colors.orange
            : Colors.green,
      ),
    );
  }

  Future<void> _copyDiagnosticLogTail() async {
    final path = await DiagnosticLogService.instance.logFilePath();
    final tail = await DiagnosticLogService.instance.tail(maxLines: 400);
    await Clipboard.setData(
      ClipboardData(text: '诊断日志路径: ${path ?? '无持久化日志路径'}\n\n$tail'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(path == null ? '已复制当前诊断日志内容' : '已复制诊断日志内容和路径'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _openDiagnosticLogLocation() async {
    final path = await DiagnosticLogService.instance.logFilePath();
    if (path == null || path.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前平台没有可打开的诊断日志文件'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final file = File(path);
    try {
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,${file.path}']);
      } else {
        await Process.run('xdg-open', [file.parent.path]);
      }
    } catch (error) {
      await Clipboard.setData(ClipboardData(text: path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('打开日志位置失败，已复制路径：$error'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已打开诊断日志位置'), backgroundColor: Colors.green),
    );
  }

  Future<void> _approveDesktopControlRequest(String id) async {
    final item = await DesktopControlBridge.instance.approvePendingRequest(id);
    await _refreshDesktopControlStatus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(item == null ? '确认请求已失效' : '已允许该动作，工具可继续执行'),
        backgroundColor: item == null ? Colors.orange : Colors.green,
      ),
    );
  }

  Future<void> _rejectDesktopControlRequest(String id) async {
    final item = await DesktopControlBridge.instance.rejectPendingRequest(id);
    await _refreshDesktopControlStatus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(item == null ? '确认请求已失效' : '已拒绝该动作'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  String _feedbackPlatformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  Future<Map<String, dynamic>> _submitFeedback({
    required String title,
    required String description,
    required String contact,
  }) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);

    return ApiClient.instance.post(
      WorkerConfig.getEndpoint('submitFeedback'),
      body: {
        'title': title,
        'description': description,
        if (contact.trim().isNotEmpty) 'contact': contact.trim(),
        'page': 'settings_screen',
        'platform': _feedbackPlatformLabel(),
        'appVersion': _appVersionLabel,
      },
      token: authModel.authToken,
    );
  }

  Future<void> _showFeedbackDialog() async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final contactController = TextEditingController(
      text: authModel.currentUser?.email ?? '',
    );
    String? validationMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> handleSubmit() async {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();
              final contact = contactController.text.trim();

              if (title.isEmpty) {
                setDialogState(() => validationMessage = '请填写问题标题');
                return;
              }

              if (description.isEmpty) {
                setDialogState(() => validationMessage = '请填写问题描述');
                return;
              }

              setDialogState(() => validationMessage = null);
              if (mounted) {
                setState(() => _isSubmittingFeedback = true);
              }

              final result = await _submitFeedback(
                title: title,
                description: description,
                contact: contact,
              );

              if (!mounted) return;
              setState(() => _isSubmittingFeedback = false);

              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
              }

              final success = result['success'] == true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? (result['message'] ?? '反馈已提交')
                        : (result['error'] ?? '反馈提交失败，请稍后重试'),
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text(
                '提交问题反馈',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '问题会通过邮件发送到支持团队，方便后续跟进。',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '当前版本：$_appVersionLabel',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        enabled: !_isSubmittingFeedback,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: '问题标题',
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: '例如：收藏后没有提示',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        enabled: !_isSubmittingFeedback,
                        style: const TextStyle(color: Colors.white),
                        minLines: 4,
                        maxLines: 8,
                        decoration: InputDecoration(
                          labelText: '问题描述',
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: '请尽量写清楚发生了什么、你期待什么结果。',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contactController,
                        enabled: !_isSubmittingFeedback,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: '联系方式（选填）',
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: '邮箱、微信或其他便于回访的信息',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      if (validationMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          validationMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSubmittingFeedback
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: _isSubmittingFeedback ? null : handleSubmit,
                  child: _isSubmittingFeedback
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('提交反馈'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      descriptionController.dispose();
      contactController.dispose();
    });
  }

  /// 显示删除模型确认对话框
  Future<void> _showDeleteModelDialog() async {
    if (_selectedModel == null) return;

    final config = LLMModelConfig.getConfig(_selectedModel!);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('删除模型', style: TextStyle(color: Colors.white)),
        content: Text(
          '确定要删除 ${config.displayName} 吗？\n\n删除后需要重新下载才能使用。',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 执行删除
      await LLMModelManager.instance.deleteModel(_selectedModel!);

      // 刷新模型状态
      final newStatus = await LLMModelManager.instance.getAllModelStatus();
      if (mounted) {
        setState(() {
          _modelStatus = newStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${config.displayName} 已删除'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: desktop
              ? null
              : AppBar(
                  title: const Text('设置'),
                  backgroundColor: const Color(0xFF121212),
                  foregroundColor: Colors.white,
                ),
          backgroundColor: desktop
              ? const Color(0xFFEDEEEE)
              : const Color(0xFF121212),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : desktop
              ? _buildSettingsDesktopLayout()
              : _buildSettingsMobileList(),
        );
      },
    );
  }

  Widget _buildSettingsMobileList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (AiBackendPolicy.isDesktopNative) ...[
            _buildOpenClawSettingCard(),
            const SizedBox(height: 12),
          ],
          if (Platform.isAndroid)
            _buildSettingItem(
              context,
              icon: Icons.battery_saver,
              iconColor: Colors.green,
              title: '后台保活设置',
              subtitle: '防止应用被系统清理',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KeepAliveGuideScreen()),
              ),
            ),
          _buildSettingItem(
            context,
            icon: Icons.refresh,
            iconColor: Colors.cyan,
            title: '刷新数据',
            subtitle: '重新同步账户信息',
            onTap: _refreshAccountData,
          ),
          _buildSettingItem(
            context,
            icon: Icons.visibility_outlined,
            iconColor: Colors.purpleAccent,
            title: '修行隐私',
            subtitle: '控制修行排行榜与公开记录的展示范围',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PracticePrivacyScreen()),
            ),
          ),
          _buildSettingItem(
            context,
            icon: Icons.help_outline,
            iconColor: Colors.orange,
            title: '帮助与反馈',
            subtitle: '提交问题或建议，发送到支持邮箱',
            onTap: _showFeedbackDialog,
          ),
          _buildSettingItem(
            context,
            icon: Icons.info_outline,
            iconColor: Colors.blue,
            title: '关于',
            subtitle: '版本 $_appVersionLabel',
            onTap: _showAbout,
          ),
          _buildDeleteAccountItem(context),
          _buildLogoutItem(context),
        ],
      ),
    );
  }

  Widget _buildSettingsDesktopLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: Container(
          margin: const EdgeInsets.all(30),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildSettingsCategorySidebar(),
              Expanded(child: _buildSettingsCategoryContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCategorySidebar() {
    final categories = [
      ('account', Icons.person_outline, '账户管理'),
      ('system', Icons.settings_outlined, '系统设置'),
      ('agent', Icons.extension_outlined, '智能体设置'),
      ('memory', Icons.psychology_outlined, '记忆'),
      ('model', Icons.view_in_ar_outlined, '模型'),
      ('data', Icons.storage_outlined, '数据管理'),
      ('security', Icons.shield_outlined, '安全中心'),
      ('help', Icons.help_outline, '帮助与反馈'),
    ];

    return Container(
      width: 250,
      color: const Color(0xFFF0F1F0),
      padding: const EdgeInsets.fromLTRB(12, 34, 12, 20),
      child: Column(
        children: [
          for (final item in categories)
            _SettingsCategoryTile(
              icon: item.$2,
              label: item.$3,
              selected: _settingsCategory == item.$1,
              onTap: () => setState(() => _settingsCategory = item.$1),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsCategoryContent() {
    final title = switch (_settingsCategory) {
      'account' => '账户管理',
      'agent' => '智能体设置',
      'memory' => '记忆',
      'model' => '模型',
      'data' => '数据管理',
      'security' => '安全中心',
      'help' => '帮助与反馈',
      _ => '设置',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 34, 36, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF202124),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Column(children: _settingsCategoryWidgets()),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _settingsCategoryWidgets() {
    switch (_settingsCategory) {
      case 'account':
        return [
          _SettingsLightRow(
            icon: Icons.refresh,
            title: '刷新数据',
            subtitle: '重新同步账户信息。',
            onTap: _refreshAccountData,
          ),
          _SettingsLightRow(
            icon: Icons.info_outline,
            title: '关于',
            subtitle: '版本 $_appVersionLabel',
            onTap: _showAbout,
          ),
          _buildLogoutItem(context),
        ];
      case 'agent':
        return [
          if (AiBackendPolicy.isDesktopNative) _buildOpenClawSettingCard(),
          _SettingsLightRow(
            icon: Icons.auto_awesome,
            title: '技能自动更新',
            subtitle: '保持已安装技能为最新版。',
            trailing: Switch(value: true, onChanged: (_) {}),
          ),
        ];
      case 'memory':
        return [
          _SettingsLightRow(
            icon: Icons.history,
            title: '对话记忆',
            subtitle: '管理本机对话上下文和项目空间。',
            onTap: _copyDiagnosticLogTail,
          ),
          _SettingsLightRow(
            icon: Icons.article_outlined,
            title: '诊断日志',
            subtitle: '复制或打开 OpenClaw 和桌面控制日志。',
            onTap: _openDiagnosticLogLocation,
          ),
        ];
      case 'model':
        return [_buildModelSettingCard()];
      case 'data':
        return [
          _buildTtsMuteSettingItem(),
          _buildRecitationThresholdSettings(),
        ];
      case 'security':
        return [
          _SettingsLightRow(
            icon: Icons.visibility_outlined,
            title: '修行隐私',
            subtitle: '控制修行排行榜与公开记录的展示范围。',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PracticePrivacyScreen()),
            ),
          ),
          _buildDeleteAccountItem(context),
        ];
      case 'help':
        return [
          _SettingsLightRow(
            icon: Icons.help_outline,
            title: '帮助与反馈',
            subtitle: '提交问题或建议，发送到支持邮箱。',
            onTap: _showFeedbackDialog,
          ),
          _SettingsLightRow(
            icon: Icons.info_outline,
            title: '关于',
            subtitle: '版本 $_appVersionLabel',
            onTap: _showAbout,
          ),
        ];
      default:
        return [
          _SettingsLightRow(
            icon: Icons.language,
            title: '显示语言',
            subtitle: '设置应用程序界面的显示语言。',
            trailing: const Text('中文(简体)'),
          ),
          _SettingsLightRow(
            icon: Icons.keyboard_return,
            title: '发送消息',
            subtitle: '设置聊天输入框中发送消息的快捷键。',
            trailing: const Text('Enter'),
          ),
          _SettingsLightRow(
            icon: Icons.open_in_full,
            title: '桌面窗口',
            subtitle: '已允许调整大小、最大化和系统全屏。',
          ),
          if (Platform.isAndroid)
            _SettingsLightRow(
              icon: Icons.battery_saver,
              title: '后台保活设置',
              subtitle: '防止应用被系统清理。',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KeepAliveGuideScreen()),
              ),
            ),
        ];
    }
  }

  Future<void> _refreshAccountData() async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    await authModel.refreshUserInfo();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('数据已刷新'), backgroundColor: Colors.green),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: _appVersionLabel,
      children: [const Text('传播佛法，利益众生')],
    );
  }

  Widget _buildOpenClawSettingCard() {
    final mode = aiBackendModeFromStorageName(_aiBackendModeName);
    final status = _openClawStatus;
    final desktopStatus = _desktopControlStatus;
    final chromeStatus = desktopStatus?.chrome;
    final remoteGatewayConfigured = _openClawRemoteGatewayUrl.trim().isNotEmpty;
    final statusColor = switch (status?.state) {
      OpenClawRuntimeState.running => Colors.greenAccent,
      OpenClawRuntimeState.starting => Colors.amberAccent,
      OpenClawRuntimeState.notBundled => Colors.orangeAccent,
      OpenClawRuntimeState.failed => Colors.redAccent,
      OpenClawRuntimeState.unsupported => Colors.white38,
      _ => Colors.white54,
    };

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.hub_outlined,
                    color: Colors.greenAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '桌面 AI / OpenClaw',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '桌面首页 AI 对话使用本机 OpenClaw，经云端代理计量',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: mode.storageName,
              dropdownColor: const Color(0xFF2A2A2A),
              decoration: InputDecoration(
                labelText: 'AI 后端',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              items: AiBackendMode.values
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.storageName,
                      child: Text('${item.label} · ${item.description}'),
                    ),
                  )
                  .toList(),
              onChanged: _isRestartingOpenClaw ? null : _setAiBackendModeName,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, color: Colors.white70),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'DeepSeek API Key 由大乘后端托管；本机 OpenClaw 使用会员登录凭证请求代理并计量 token。',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 10, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status == null
                          ? '尚未检测本机 OpenClaw 状态'
                          : '${status.label} · ${status.message}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildDesktopControlStatusRow(
              icon: Icons.mouse_outlined,
              title: '桌面控制',
              message: desktopStatus == null
                  ? '尚未检测桌面控制桥'
                  : desktopStatus.message,
              color: desktopStatus == null
                  ? Colors.white38
                  : !desktopStatus.enabledByBuild
                  ? Colors.orangeAccent
                  : desktopStatus.supportedPlatform &&
                        desktopStatus.bridgeRunning
                  ? Colors.greenAccent
                  : Colors.amberAccent,
            ),
            const SizedBox(height: 8),
            _buildDesktopControlStatusRow(
              icon: Icons.security_outlined,
              title: '权限',
              message: desktopStatus == null
                  ? '尚未检测权限'
                  : '屏幕录制 ${desktopStatus.screenRecordingGranted ? '已授权' : '未授权'} · 辅助功能 ${desktopStatus.accessibilityGranted ? '已授权' : '未授权'}',
              color:
                  desktopStatus != null &&
                      desktopStatus.screenRecordingGranted &&
                      desktopStatus.accessibilityGranted
                  ? Colors.greenAccent
                  : Colors.orangeAccent,
            ),
            const SizedBox(height: 8),
            _buildDesktopControlStatusRow(
              icon: Icons.qr_code_2_outlined,
              title: '远程入口',
              message: remoteGatewayConfigured
                  ? _openClawRemoteGatewayUrl
                  : '未配置公网 wss:// 或 Tailscale Serve/Funnel 入口',
              color: remoteGatewayConfigured
                  ? Colors.greenAccent
                  : Colors.orangeAccent,
            ),
            const SizedBox(height: 8),
            _buildDesktopControlStatusRow(
              icon: Icons.public,
              title: 'Chrome 连接器',
              message: chromeStatus?.message ?? '尚未检测 Chrome 连接器',
              color: chromeStatus?.connected == true
                  ? Colors.greenAccent
                  : Colors.orangeAccent,
            ),
            if (_desktopControlPending.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPendingDesktopConfirmations(),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isRestartingOpenClaw || _isRunningOpenClawCli
                        ? null
                        : _refreshOpenClawStatus,
                    icon: const Icon(
                      Icons.health_and_safety_outlined,
                      size: 18,
                    ),
                    label: const Text('检测'),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _isRestartingOpenClaw || _isRunningOpenClawCli
                      ? null
                      : () => unawaited(_restartOpenClawRuntime()),
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: Text(_isRestartingOpenClaw ? '启动中' : '重启本机 AI'),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: '高级操作',
                  enabled:
                      !_isRestartingOpenClaw &&
                      !_isRunningOpenClawCli &&
                      !_isPreparingChromeConnector,
                  onSelected: (value) {
                    switch (value) {
                      case 'restart':
                        unawaited(_restartOpenClawRuntime());
                        break;
                      case 'tools':
                        unawaited(
                          _refreshDesktopControlStatus(startBridge: true),
                        );
                        break;
                      case 'connector':
                        unawaited(_prepareChromeConnectorInstall());
                        break;
                      case 'remote':
                        unawaited(_editOpenClawRemoteGatewayUrl());
                        break;
                      case 'mobile':
                        unawaited(_createOpenClawMobilePairingCode());
                        break;
                      case 'wechatPlugin':
                        unawaited(_installOpenClawWeChatPlugin());
                        break;
                      case 'wechatLogin':
                        unawaited(_loginOpenClawWeChat());
                        break;
                      case 'channels':
                        unawaited(_inspectOpenClawChannels());
                        break;
                      case 'permissions':
                        unawaited(
                          _requestDesktopPermission(
                            screenRecording:
                                desktopStatus?.screenRecordingGranted != true,
                          ),
                        );
                        break;
                      case 'copyLog':
                        unawaited(_copyDiagnosticLogTail());
                        break;
                      case 'openLog':
                        unawaited(_openDiagnosticLogLocation());
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'tools', child: Text('工具诊断')),
                    PopupMenuItem(
                      value: 'connector',
                      child: Text(_isPreparingChromeConnector ? '准备中' : '连接器'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'remote', child: Text('远程入口')),
                    const PopupMenuItem(value: 'mobile', child: Text('移动配对')),
                    const PopupMenuItem(
                      value: 'wechatPlugin',
                      child: Text('微信插件'),
                    ),
                    const PopupMenuItem(
                      value: 'wechatLogin',
                      child: Text('微信登录'),
                    ),
                    const PopupMenuItem(value: 'channels', child: Text('渠道状态')),
                    const PopupMenuItem(
                      value: 'permissions',
                      child: Text('系统权限'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'copyLog', child: Text('复制日志')),
                    const PopupMenuItem(value: 'openLog', child: Text('日志位置')),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Icon(Icons.more_horiz, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopControlStatusRow({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingDesktopConfirmations() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amberAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '待确认动作',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ..._desktopControlPending.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.summary,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _rejectDesktopControlRequest(item.id),
                    child: const Text('拒绝'),
                  ),
                  FilledButton(
                    onPressed: () => _approveDesktopControlRequest(item.id),
                    child: const Text('允许'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// AI模型设置卡片
  Widget _buildModelSettingCard() {
    final LLMModelConfig? selectedConfig;
    final ModelStatus? selectedStatus;

    if (_selectedModel != null) {
      selectedConfig = LLMModelConfig.getConfig(_selectedModel!);
      selectedStatus = _modelStatus?[_selectedModel!];
    } else {
      selectedConfig = null;
      selectedStatus = null;
    }

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Colors.purple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 模型',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '用于语义分析和智能推理',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 设备信息提示
            if (_deviceInfo != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_android,
                      color: Colors.blue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '内存 ${_deviceInfo!.ramString} | ${_deviceInfo!.levelString}设备',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // 当前模型信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedModel == LLMModelType.deepseekR1
                        ? Icons.lightbulb
                        : Icons.memory,
                    color: selectedConfig != null ? Colors.amber : Colors.grey,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedConfig?.displayName ?? '未选择模型',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (selectedConfig != null)
                          Text(
                            '${selectedConfig.sizeString} | ${selectedStatus == ModelStatus.downloaded ? "已下载" : "未下载"}',
                            style: TextStyle(
                              color: selectedStatus == ModelStatus.downloaded
                                  ? Colors.green
                                  : Colors.orange,
                              fontSize: 12,
                            ),
                          )
                        else
                          const Text(
                            '请选择一个 AI 模型',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 状态指示
                  if (selectedStatus == ModelStatus.downloaded)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    )
                  else if (selectedStatus == ModelStatus.downloading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.amber,
                      ),
                    )
                  else
                    const Icon(Icons.download, color: Colors.orange, size: 20),
                ],
              ),
            ),

            // 下载进度显示（仅在下载中时显示）
            if (_isDownloading) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _downloadStage.isNotEmpty
                                ? _downloadStage
                                : '下载中...',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.amber,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // 切换模型按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await ModelSelectionDialog.show(context);
                  if (result != null) {
                    setState(() {
                      _selectedModel = result;
                    });
                    // 刷新模型状态
                    final newStatus = await LLMModelManager.instance
                        .getAllModelStatus();
                    if (mounted) {
                      setState(() {
                        _modelStatus = newStatus;
                      });
                    }
                  }
                },
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(_selectedModel == null ? '选择模型' : '切换模型'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple,
                  side: const BorderSide(color: Colors.purple),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // 删除模型按钮（仅当模型已下载时显示）
            if (_selectedModel != null &&
                selectedStatus == ModelStatus.downloaded)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteModelDialog(),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('删除模型'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// TTS默认静音设置项
  Widget _buildTtsMuteSettingItem() {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.volume_off, color: Colors.amber, size: 24),
        ),
        title: const Text(
          '启动默认静音',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _defaultTtsMuted ? '法流页面TTS朗读默认静音' : '法流页面TTS朗读默认开启',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        trailing: Switch(
          value: _defaultTtsMuted,
          onChanged: _setDefaultTtsMuted,
          activeColor: Colors.amber,
        ),
      ),
    );
  }

  /// 读诵匹配阈值设置
  Widget _buildRecitationThresholdSettings() {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.record_voice_over,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '读诵识别灵敏度',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '调整智能识别的切换阈值',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 快速切换阈值
            Row(
              children: [
                const Text(
                  '快速切换',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(_fastMatchThreshold * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Slider(
              value: _fastMatchThreshold,
              min: 0.3,
              max: 1.0,
              divisions: 14,
              activeColor: Colors.green,
              inactiveColor: Colors.green.withOpacity(0.3),
              onChanged: _setFastMatchThreshold,
            ),
            const Text(
              '匹配度达到此值时立即切换下一句',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),

            const SizedBox(height: 16),

            // 普通匹配阈值
            Row(
              children: [
                const Text(
                  '普通匹配',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(_matchThreshold * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Slider(
              value: _matchThreshold,
              min: 0.3,
              max: 1.0,
              divisions: 14,
              activeColor: Colors.amber,
              inactiveColor: Colors.amber.withOpacity(0.3),
              onChanged: _setMatchThreshold,
            ),
            const Text(
              '匹配度达到此值且检测到停顿时切换',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: onTap,
      ),
    );
  }

  /// 退出登录按钮
  Widget _buildLogoutItem(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.logout, color: Colors.redAccent, size: 24),
        ),
        title: const Text(
          '退出登录',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: const Text(
          '退出当前账号',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('确认退出', style: TextStyle(color: Colors.white)),
              content: const Text(
                '确定要退出登录吗？',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    '退出',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          );
          if (confirm == true) {
            final authModel = Provider.of<AuthModel>(context, listen: false);
            await authModel.logout();
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已退出登录')));
              Navigator.pop(context); // 返回上一页
            }
          }
        },
      ),
    );
  }

  /// 注销账户按钮
  Widget _buildDeleteAccountItem(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.person_remove, color: Colors.red, size: 24),
        ),
        title: const Text(
          '注销账户',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
        ),
        subtitle: const Text(
          '此操作不可逆，将永久删除您的数据',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text(
                '风险警告',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: const Text(
                '您正在申请注销账户。\n\n注销后，您的所有个人数据、记录与设置将被彻底删除，并且无法恢复。确定要继续吗？',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    '点错了，取消',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    '确定注销',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          );

          if (confirm == true) {
            // 提供双重认证防止误操作
            if (!context.mounted) return;
            final doubleConfirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                title: const Text(
                  '最终确认',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: const Text(
                  '账户删除后将彻底丢失，不可找回，这是最后的确认，还要继续吗？',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      '取消',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      '确认删除账户',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );

            if (doubleConfirm == true) {
              if (!context.mounted) return;

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return const Center(child: CircularProgressIndicator());
                },
              );

              final authModel = Provider.of<AuthModel>(context, listen: false);
              final res = await authModel.deleteAccount();

              if (!context.mounted) return;
              Navigator.pop(context); // close loading indicator

              if (res['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('账户已成功注销'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context); // 返回上一页到未登录状态页面
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['error'] ?? '注销失败，请重试或联系客服'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }
}

class _SettingsCategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SettingsCategoryTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 42,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE0E0DF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF26282B), size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF26282B),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsLightRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsLightRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F6F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF303236), size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF252729),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF73777A),
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 16),
                DefaultTextStyle(
                  style: const TextStyle(
                    color: Color(0xFF303236),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  child: trailing!,
                ),
              ] else if (onTap != null)
                const Icon(Icons.chevron_right, color: Color(0xFF9EA1A3)),
            ],
          ),
        ),
      ),
    );
  }
}
