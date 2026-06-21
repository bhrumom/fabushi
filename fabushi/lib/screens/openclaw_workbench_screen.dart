import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../core/design_system/app_theme.dart';
import '../models/auth_model.dart';
import '../services/ai_backend_policy.dart';
import '../services/app_settings.dart';
import '../services/dacheng_ai_service.dart';
import '../services/desktop_control/desktop_control_bridge.dart';
import '../services/desktop_control/desktop_control_models.dart';
import '../services/diagnostic_log_service.dart';
import '../services/openclaw/openclaw_runtime.dart';

enum _WorkbenchSection { newTask, assistant, projects, experts, automation }

enum _MarketTab { experts, skills, connectors }

class OpenClawWorkbenchScreen extends StatefulWidget {
  const OpenClawWorkbenchScreen({super.key});

  @override
  State<OpenClawWorkbenchScreen> createState() =>
      _OpenClawWorkbenchScreenState();
}

class _OpenClawWorkbenchScreenState extends State<OpenClawWorkbenchScreen> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _messagesController = ScrollController();
  final DachengAiService _aiService = DachengAiService();
  final List<_WorkbenchMessage> _messages = [];
  late final Map<_WorkbenchSection, ScrollController> _contentScrollControllers;

  StreamSubscription<DachengAiStreamEvent>? _streamSubscription;
  _WorkbenchSection _section = _WorkbenchSection.newTask;
  _MarketTab _marketTab = _MarketTab.experts;
  String _scene = '日常助理';
  String _mode = '自动';
  String _permissionMode = '默认权限';
  String? _conversationId;
  String _streamingText = '';
  String _activityText = '';
  int _requestSerial = 0;

  bool _isLoadingStatus = true;
  bool _isRunningAction = false;
  bool _isSending = false;
  bool _isRestarting = false;
  bool _isPreparingConnector = false;
  String _remoteGatewayUrl = '';
  OpenClawRuntimeStatus? _openClawStatus;
  DesktopControlBridgeStatus? _desktopStatus;

  @override
  void initState() {
    super.initState();
    _contentScrollControllers = {
      _WorkbenchSection.newTask: ScrollController(),
      _WorkbenchSection.projects: ScrollController(),
      _WorkbenchSection.experts: ScrollController(),
      _WorkbenchSection.automation: ScrollController(),
    };
    _messages.add(
      const _WorkbenchMessage(
        text: '我已经接入本机 OpenClaw。可以让我整理资料、操作浏览器、处理文件、连接微信/移动端，或把任务交给桌面工具执行。',
        isUser: false,
      ),
    );
    unawaited(_loadRuntimeStatus(probeOpenClaw: false));
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _promptController.dispose();
    for (final controller in _contentScrollControllers.values) {
      controller.dispose();
    }
    _messagesController.dispose();
    super.dispose();
  }

  Future<void> _loadRuntimeStatus({required bool probeOpenClaw}) async {
    if (!AiBackendPolicy.isDesktopNative) {
      if (mounted) setState(() => _isLoadingStatus = false);
      return;
    }
    try {
      final values = await Future.wait<dynamic>([
        AppSettings.getOpenClawRemoteGatewayUrl(),
        OpenClawRuntime.instance
            .getStatus(probe: probeOpenClaw)
            .timeout(const Duration(seconds: 8)),
        DesktopControlBridge.instance.getStatus().timeout(
          const Duration(seconds: 5),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _remoteGatewayUrl = values[0] as String;
        _openClawStatus = values[1] as OpenClawRuntimeStatus;
        _desktopStatus = values[2] as DesktopControlBridgeStatus;
        _isLoadingStatus = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _openClawStatus = OpenClawRuntimeStatus(
          state: OpenClawRuntimeState.failed,
          message: 'OpenClaw 状态检测失败：$error',
          checkedAt: DateTime.now(),
        );
        _isLoadingStatus = false;
      });
    }
  }

  Future<void> _refreshRuntimeStatus() {
    setState(() => _isLoadingStatus = true);
    return _loadRuntimeStatus(probeOpenClaw: true);
  }

  Future<void> _restartOpenClaw() async {
    if (!AiBackendPolicy.isDesktopNative || _isRestarting) return;
    setState(() => _isRestarting = true);
    OpenClawRuntimeStatus status;
    try {
      status = await OpenClawRuntime.instance.restart().timeout(
        const Duration(seconds: 75),
      );
    } catch (error) {
      status = OpenClawRuntimeStatus(
        state: OpenClawRuntimeState.failed,
        message: 'OpenClaw 重启失败：$error',
        checkedAt: DateTime.now(),
      );
    }
    if (!mounted) return;
    setState(() {
      _openClawStatus = status;
      _isRestarting = false;
    });
    unawaited(_loadRuntimeStatus(probeOpenClaw: true));
    _showSnack(
      status.isHealthy ? '本机 OpenClaw 已启动' : status.message,
      ok: status.isHealthy,
    );
  }

  Future<void> _runOpenClawAction(
    String label,
    Future<OpenClawCliResult> Function() action,
  ) async {
    if (!AiBackendPolicy.isDesktopNative || _isRunningAction) return;
    setState(() => _isRunningAction = true);
    OpenClawCliResult? result;
    Object? error;
    try {
      result = await action();
    } catch (err) {
      error = err;
    }
    if (!mounted) return;
    setState(() => _isRunningAction = false);
    if (result == null) {
      _showSnack('$label 失败：$error', ok: false);
      return;
    }
    await _showCliResult(label, result);
    unawaited(_loadRuntimeStatus(probeOpenClaw: true));
  }

  Future<void> _showCliResult(String title, OpenClawCliResult result) async {
    final output = [
      result.command,
      'exitCode=${result.exitCode}${result.timedOut ? ' · timed out' : ''}',
      if (result.combinedOutput.trim().isNotEmpty) '',
      if (result.combinedOutput.trim().isNotEmpty) result.combinedOutput,
    ].join('\n');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 620,
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

  Future<void> _editRemoteGatewayUrl() async {
    final controller = TextEditingController(text: _remoteGatewayUrl);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('远程入口'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'wss://...',
            helperText: '用于移动端、微信、小程序从公网远程连接这台电脑',
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
    setState(() => _remoteGatewayUrl = value.trim());
    _showSnack('已保存远程入口，重启本机 AI 后生效');
  }

  Future<void> _createMobilePairingCode() async {
    if (_remoteGatewayUrl.trim().isEmpty) {
      await _editRemoteGatewayUrl();
      if (_remoteGatewayUrl.trim().isEmpty) return;
    }
    await _runOpenClawAction(
      '移动端配对码',
      () => OpenClawRuntime.instance.createMobilePairingCode(remote: true),
    );
  }

  Future<void> _prepareChromeConnector() async {
    if (_isPreparingConnector) return;
    setState(() => _isPreparingConnector = true);
    String? path;
    Object? error;
    try {
      path = await DesktopControlBridge.instance
          .prepareChromeConnectorInstall()
          .timeout(const Duration(seconds: 20));
    } catch (err) {
      error = err;
    }
    if (!mounted) return;
    setState(() => _isPreparingConnector = false);
    unawaited(_loadRuntimeStatus(probeOpenClaw: true));
    _showSnack(
      error != null
          ? 'Chrome 连接器准备失败：$error'
          : path == null
          ? '当前构建未启用 Chrome 连接器'
          : 'Chrome 连接器目录已打开',
      ok: error == null,
    );
  }

  Future<void> _requestDesktopPermission({
    required bool screenRecording,
  }) async {
    final result = screenRecording
        ? await DesktopControlBridge.instance.requestScreenRecordingPermission()
        : await DesktopControlBridge.instance.requestAccessibilityPermission();
    await _loadRuntimeStatus(probeOpenClaw: true);
    if (!mounted) return;
    _showSnack(result['message']?.toString() ?? '已打开系统权限请求');
  }

  Future<void> _copyDiagnosticLogTail() async {
    final path = await DiagnosticLogService.instance.logFilePath();
    final tail = await DiagnosticLogService.instance.tail(maxLines: 400);
    await Clipboard.setData(
      ClipboardData(text: '诊断日志路径: ${path ?? '无持久化日志路径'}\n\n$tail'),
    );
    if (!mounted) return;
    _showSnack(path == null ? '已复制当前诊断日志内容' : '已复制诊断日志内容和路径');
  }

  Future<void> _openDiagnosticLogLocation() async {
    final path = await DiagnosticLogService.instance.logFilePath();
    if (path == null || path.isEmpty) {
      _showSnack('当前平台没有可打开的诊断日志文件', ok: false);
      return;
    }
    try {
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,$path']);
      } else {
        await Process.run('xdg-open', [File(path).parent.path]);
      }
      _showSnack('已打开诊断日志位置');
    } catch (error) {
      await Clipboard.setData(ClipboardData(text: path));
      _showSnack('打开日志位置失败，已复制路径：$error', ok: false);
    }
  }

  void _prefillPrompt(String text) {
    setState(() {
      _promptController.text = text;
      _promptController.selection = TextSelection.collapsed(
        offset: _promptController.text.length,
      );
      _section = _WorkbenchSection.newTask;
    });
    _resetContentScroll();
  }

  void _selectSection(_WorkbenchSection section, {_MarketTab? marketTab}) {
    setState(() {
      _section = section;
      if (marketTab != null) _marketTab = marketTab;
    });
    _resetContentScroll();
  }

  void _resetContentScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _contentScrollControllers[_section];
      if (controller == null || !controller.hasClients) return;
      controller.jumpTo(0);
    });
  }

  Future<void> _sendPrompt() async {
    final text = _promptController.text.trim();
    if (text.isEmpty || _isSending) return;
    HapticFeedback.lightImpact();
    final serial = ++_requestSerial;
    final auth = context.read<AuthModel>();
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    setState(() {
      _promptController.clear();
      _messages.add(_WorkbenchMessage(text: text, isUser: true));
      _isSending = true;
      _streamingText = '';
      _activityText = '正在思考';
      _section = _WorkbenchSection.assistant;
    });
    _scrollMessages();

    try {
      var finalText = '';
      var latestConversationId = _conversationId;
      await for (final event in _aiService.sendChatStream(
        message: text,
        conversationId: _conversationId,
        token: auth.authToken,
        username: auth.currentUser?.username,
        isMember: auth.hasPermission('premium'),
      )) {
        if (!mounted || serial != _requestSerial) return;
        if (event.conversationId != null && event.conversationId!.isNotEmpty) {
          latestConversationId = event.conversationId;
        }
        if (event.isStep) {
          _activityText = _visibleStep(event) ?? _activityText;
        } else if (event.isDelta) {
          finalText += event.text;
          _activityText = '正在生成';
        } else if (event.isDone) {
          latestConversationId = event.conversationId ?? latestConversationId;
          finalText = (event.raw['message'] ?? finalText).toString();
        } else if (event.isError) {
          throw StateError(event.text.isEmpty ? '大乘 AI 生成失败' : event.text);
        }
        setState(() {
          _conversationId = latestConversationId;
          _streamingText = finalText;
        });
        _scrollMessages();
      }
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        if (finalText.trim().isNotEmpty) {
          _messages.add(
            _WorkbenchMessage(text: finalText.trim(), isUser: false),
          );
        }
        _streamingText = '';
        _activityText = '';
        _isSending = false;
        _conversationId = latestConversationId;
      });
      _scrollMessages();
    } catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _messages.add(
          _WorkbenchMessage(
            text: '大乘 AI 生成失败：$error',
            isUser: false,
            isError: true,
          ),
        );
        _streamingText = '';
        _activityText = '';
        _isSending = false;
      });
      _scrollMessages();
    }
  }

  void _stopGeneration() {
    _requestSerial++;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    setState(() {
      if (_streamingText.trim().isNotEmpty) {
        _messages.add(_WorkbenchMessage(text: _streamingText, isUser: false));
      }
      _streamingText = '';
      _activityText = '';
      _isSending = false;
    });
  }

  String? _visibleStep(DachengAiStreamEvent event) {
    final title = (event.raw['title'] ?? '').toString().trim();
    final message = (event.raw['message'] ?? event.text).toString().trim();
    final combined = [
      title,
      message,
    ].where((item) => item.isNotEmpty).join(' ');
    if (combined.isEmpty) return null;
    if (RegExp(r'执行|调用|搜索|下载|浏览器|文件|微信|工具|MCP').hasMatch(combined)) {
      return title.isNotEmpty ? title : message;
    }
    return null;
  }

  void _scrollMessages() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesController.hasClients) return;
      _messagesController.animateTo(
        _messagesController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnack(String text, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: ok ? Colors.green : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F6),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            return Row(
              children: [
                if (wide) _buildSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      if (!wide) _buildMobileTopTabs(),
                      Expanded(child: _buildMainContent(wide: wide)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 256,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFEFEFED),
        border: Border(right: BorderSide(color: Color(0xFFE0E0DD))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '收起侧边栏',
                onPressed: () {},
                icon: const Icon(Icons.view_sidebar_outlined),
              ),
              const Spacer(),
              IconButton(
                tooltip: '搜索',
                onPressed: () => _prefillPrompt('搜索我本机和对话里的资料'),
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: '筛选',
                onPressed: () {},
                icon: const Icon(Icons.filter_alt_outlined),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            '大乘 OpenClaw',
            style: TextStyle(
              color: Color(0xFF9B9B9A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _SidebarItem(
            icon: Icons.add_comment_outlined,
            label: '新建任务',
            selected: _section == _WorkbenchSection.newTask,
            onTap: () => _selectSection(_WorkbenchSection.newTask),
          ),
          _SidebarItem(
            icon: Icons.smart_toy_outlined,
            label: '助理',
            selected: _section == _WorkbenchSection.assistant,
            onTap: () => _selectSection(_WorkbenchSection.assistant),
          ),
          _SidebarItem(
            icon: Icons.account_tree_outlined,
            label: '项目',
            selected: _section == _WorkbenchSection.projects,
            onTap: () => _selectSection(_WorkbenchSection.projects),
          ),
          _SidebarItem(
            icon: Icons.hub_outlined,
            label: '专家',
            trailing: '技能·连接器',
            selected: _section == _WorkbenchSection.experts,
            onTap: () => _selectSection(_WorkbenchSection.experts),
          ),
          _SidebarItem(
            icon: Icons.alarm_on_outlined,
            label: '自动化',
            selected: _section == _WorkbenchSection.automation,
            onTap: () => _selectSection(_WorkbenchSection.automation),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: _handleMoreSelection,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'files', child: Text('我的文件')),
              PopupMenuItem(value: 'docs', child: Text('腾讯文档')),
              PopupMenuItem(value: 'knowledge', child: Text('知识库')),
              PopupMenuItem(value: 'ideas', child: Text('灵感')),
            ],
            child: const _SidebarItem(
              icon: Icons.apps_outlined,
              label: '更多',
              trailing: '资料库·灵感',
              selected: false,
            ),
          ),
          const SizedBox(height: 26),
          const _SidebarGroupTitle('任务 (3)'),
          _RecentTask(
            title: '用微信远程让电脑处理资料',
            onTap: () => _prefillPrompt('帮我设置微信远程控制这台电脑'),
          ),
          _RecentTask(
            title: '操作浏览器并整理截图',
            onTap: () => _prefillPrompt('打开浏览器，帮我整理当前页面信息'),
          ),
          _RecentTask(
            title: '公众号自动发文技能',
            onTap: () => _prefillPrompt('帮我用微信公众号草稿发布技能处理这篇文章'),
          ),
          const SizedBox(height: 18),
          const _SidebarGroupTitle('空间 (3)'),
          _SpaceItem(
            title: '法布施项目',
            subtitle: '发布、资源、素材',
            onTap: () => _selectSection(_WorkbenchSection.projects),
          ),
          _SpaceItem(
            title: '本机电脑',
            subtitle: '浏览器、文件、桌面',
            onTap: () => _selectSection(
              _WorkbenchSection.experts,
              marketTab: _MarketTab.connectors,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFF00C49A),
                child: Icon(Icons.self_improvement, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.watch<AuthModel>().currentUser?.username ?? '大乘用户',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: '扫码连接',
                onPressed: _isRunningAction ? null : _createMobilePairingCode,
                icon: const Icon(Icons.qr_code_2_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTopTabs() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      color: const Color(0xFFEFEFED),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _WorkbenchSection.values.map((section) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TopSectionButton(
                label: Text(_sectionLabel(section)),
                selected: _section == section,
                onTap: () => _selectSection(section),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMainContent({required bool wide}) {
    final content = switch (_section) {
      _WorkbenchSection.newTask => _buildNewTaskView(wide: wide),
      _WorkbenchSection.assistant => _buildAssistantView(),
      _WorkbenchSection.projects => _buildProjectsView(),
      _WorkbenchSection.experts => _buildMarketView(),
      _WorkbenchSection.automation => _buildAutomationView(),
    };

    return KeyedSubtree(
      key: ValueKey('${_section.name}:${_marketTab.name}'),
      child: content,
    );
  }

  Widget _buildNewTaskView({required bool wide}) {
    return SingleChildScrollView(
      key: const PageStorageKey('openclaw-workbench-new-task'),
      controller: _contentScrollControllers[_WorkbenchSection.newTask],
      padding: EdgeInsets.fromLTRB(wide ? 56 : 18, 26, wide ? 56 : 18, 26),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _buildGrowthButton(),
              ),
              SizedBox(height: wide ? 172 : 54),
              const Text(
                '大乘',
                style: TextStyle(
                  color: Color(0xFF151515),
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '你的本地助理',
                style: TextStyle(
                  color: Color(0xFF151515),
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ['日常助理', '代码开发', '设计创意'].map((scene) {
                  final selected = _scene == scene;
                  return ChoiceChip(
                    label: Text(scene),
                    selected: selected,
                    onSelected: (_) => setState(() => _scene = scene),
                    selectedColor: const Color(0xFF2B2B2B),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF333333),
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 48),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PromptChip(
                    icon: Icons.description_outlined,
                    label: '文档处理',
                    onTap: () => _prefillPrompt('帮我把这份文档整理成清晰摘要和行动清单'),
                  ),
                  _PromptChip(
                    icon: Icons.public_outlined,
                    label: '全球法布施',
                    onTap: () => _prefillPrompt('帮我策划一次全球法布施发布任务'),
                  ),
                  _PromptChip(
                    icon: Icons.chat_bubble_outline,
                    label: '微信远程',
                    onTap: () => _prefillPrompt('帮我检查微信和移动端远程控制是否可用'),
                  ),
                  _PromptChip(
                    icon: Icons.more_horiz,
                    label: '更多',
                    onTap: () => _selectSection(_WorkbenchSection.experts),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _buildComposer()),
                  if (wide) ...[
                    const SizedBox(width: 18),
                    SizedBox(width: 270, child: _buildActivityNotice()),
                  ],
                ],
              ),
              if (!wide) ...[
                const SizedBox(height: 14),
                _buildActivityNotice(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantView() {
    return Column(
      children: [
        _buildAssistantHeader(),
        Expanded(
          child: ListView.builder(
            controller: _messagesController,
            padding: const EdgeInsets.fromLTRB(26, 20, 26, 20),
            itemCount:
                _messages.length + (_streamingText.trim().isNotEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _messages.length) {
                return _MessageBubble(
                  message: _WorkbenchMessage(
                    text: _streamingText,
                    isUser: false,
                    status: _activityText,
                  ),
                );
              }
              return _MessageBubble(message: _messages[index]);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: _buildComposer(),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectsView() {
    final templates = [
      _TemplateCardData(
        icon: Icons.public_outlined,
        title: '法布施发布全流程',
        subtitle: '素材规划、生成文案、平台发布、结果检查',
        prompt: '创建一个法布施发布项目，帮我规划素材、文案、平台和验收清单',
      ),
      _TemplateCardData(
        icon: Icons.travel_explore_outlined,
        title: '资源检索与整理',
        subtitle: '搜索经典资料、下载整理、生成摘要',
        prompt: '帮我启动资源检索项目，围绕一个主题找资料并整理成可发布内容',
      ),
      _TemplateCardData(
        icon: Icons.chat_bubble_outline,
        title: '微信运营工作台',
        subtitle: '公众号草稿、小程序、远程消息入口',
        prompt: '帮我搭建微信运营工作流，包含公众号草稿和微信远程入口',
      ),
      _TemplateCardData(
        icon: Icons.bug_report_outlined,
        title: '桌面自动化验收',
        subtitle: '浏览器、截图、文件、权限、诊断日志',
        prompt: '帮我检查桌面自动化能力，验证浏览器、截图、文件和权限',
      ),
      _TemplateCardData(
        icon: Icons.menu_book_outlined,
        title: '功课内容项目',
        subtitle: '经典、仪轨、背诵卡、学习计划',
        prompt: '帮我创建功课内容项目，整理经典、仪轨和背诵卡',
      ),
      _TemplateCardData(
        icon: Icons.task_alt_outlined,
        title: '项目交付',
        subtitle: '任务拆解、执行跟踪、产物归档',
        prompt: '帮我把当前目标拆成项目任务，并持续跟踪产物和下一步',
      ),
    ];

    return _WorkbenchPage(
      title: '项目',
      subtitle: '把本地助理能力组织成可复用工作流',
      controller: _contentScrollControllers[_WorkbenchSection.projects],
      actions: [
        FilledButton.icon(
          onPressed: () => _prefillPrompt('新建一个本机 OpenClaw 项目'),
          icon: const Icon(Icons.add),
          label: const Text('新建项目'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SearchField(hint: '搜索项目', onSubmitted: _prefillPrompt),
          const SizedBox(height: 22),
          const _SectionTitle('我的项目'),
          const SizedBox(height: 10),
          _ProjectCard(
            title: '大乘 OpenClaw 桌面端',
            subtitle: '本机助理、微信远程、移动配对、连接器',
            onTap: () => _prefillPrompt('继续完善大乘 OpenClaw 桌面端'),
          ),
          const SizedBox(height: 28),
          const _SectionTitle('从模板创建'),
          const SizedBox(height: 12),
          _ResponsiveCardGrid(
            children: templates
                .map(
                  (item) => _ActionCard(
                    icon: item.icon,
                    title: item.title,
                    subtitle: item.subtitle,
                    onTap: () => _prefillPrompt(item.prompt),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketView() {
    return _WorkbenchPage(
      title: '专家 · 技能 · 连接器',
      subtitle: '把 OpenClaw 能力做成可召唤的工作组件',
      controller: _contentScrollControllers[_WorkbenchSection.experts],
      actions: _MarketTab.values.map((tab) {
        return _TopSectionButton(
          label: Text(_marketTabLabel(tab)),
          selected: _marketTab == tab,
          onTap: () {
            setState(() => _marketTab = tab);
            _resetContentScroll();
          },
        );
      }).toList(),
      child: switch (_marketTab) {
        _MarketTab.experts => _buildExpertsMarket(),
        _MarketTab.skills => _buildSkillsMarket(),
        _MarketTab.connectors => _buildConnectorsMarket(),
      },
    );
  }

  Widget _buildExpertsMarket() {
    final scenes = [
      _TemplateCardData(
        icon: Icons.edit_note_outlined,
        title: '内容创作',
        subtitle: '文案、脚本、发布计划',
        prompt: '召唤内容创作专家，帮我把素材整理成多平台发布内容',
      ),
      _TemplateCardData(
        icon: Icons.code,
        title: '代码开发',
        subtitle: '修 bug、跑测试、看日志',
        prompt: '召唤高级开发工程师，帮我检查当前项目并修复问题',
      ),
      _TemplateCardData(
        icon: Icons.travel_explore_outlined,
        title: '浏览器操作',
        subtitle: '打开网页、截图、表单、提取信息',
        prompt: '召唤浏览器操作员，帮我操作当前浏览器并整理结果',
      ),
      _TemplateCardData(
        icon: Icons.chat_bubble_outline,
        title: '微信运营',
        subtitle: '公众号、小程序、远程消息',
        prompt: '召唤微信运营专家，帮我检查微信连接和公众号发布流程',
      ),
    ];
    final experts = [
      _TemplateCardData(
        icon: Icons.public,
        title: '全球法布施策划师',
        subtitle: '从资源到发布的完整方案',
        prompt: '召唤全球法布施策划师',
      ),
      _TemplateCardData(
        icon: Icons.developer_mode,
        title: '高级开发工程师',
        subtitle: '本机代码、构建、测试、PR',
        prompt: '召唤高级开发工程师',
      ),
      _TemplateCardData(
        icon: Icons.folder_copy_outlined,
        title: '本机文件管家',
        subtitle: '文件搜索、归档、清理建议',
        prompt: '召唤本机文件管家',
      ),
      _TemplateCardData(
        icon: Icons.auto_awesome_motion_outlined,
        title: '自动化编排员',
        subtitle: '把重复任务做成计划',
        prompt: '召唤自动化编排员',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SearchField(hint: '搜索专家职称或描述', onSubmitted: _prefillPrompt),
        const SizedBox(height: 22),
        const _SectionTitle('精选场景'),
        const SizedBox(height: 12),
        _ResponsiveCardGrid(
          children: scenes
              .map(
                (item) => _TintedSceneCard(
                  icon: item.icon,
                  title: item.title,
                  subtitle: item.subtitle,
                  onTap: () => _prefillPrompt(item.prompt),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 28),
        const _SectionTitle('专家'),
        const SizedBox(height: 12),
        _ResponsiveCardGrid(
          children: experts
              .map(
                (item) => _ActionCard(
                  icon: item.icon,
                  title: item.title,
                  subtitle: item.subtitle,
                  actionLabel: '召唤',
                  onTap: () => _prefillPrompt(item.prompt),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSkillsMarket() {
    final skills = [
      _TemplateCardData(
        icon: Icons.search,
        title: 'find-skills',
        subtitle: '发现并安装更多 OpenClaw 技能',
        prompt: '帮我查找适合当前任务的 OpenClaw 技能',
      ),
      _TemplateCardData(
        icon: Icons.campaign_outlined,
        title: 'media-auto-publisher',
        subtitle: '百家号、搜狐、知乎、公众号、小红书、抖音',
        prompt: '使用 media-auto-publisher 帮我发布这篇内容',
      ),
      _TemplateCardData(
        icon: Icons.chat_bubble_outline,
        title: 'wechat-draft-publisher',
        subtitle: 'HTML 文章发布到微信公众号草稿箱',
        prompt: '使用 wechat-draft-publisher 上传公众号草稿',
      ),
      _TemplateCardData(
        icon: Icons.public,
        title: 'Web Access',
        subtitle: '本地 Chrome 自动化与截图',
        prompt: '使用浏览器自动化打开网页并截图',
      ),
      _TemplateCardData(
        icon: Icons.picture_as_pdf_outlined,
        title: 'PDF / Word / Excel',
        subtitle: '文档读取、生成、转换、分析',
        prompt: '帮我处理一个文档文件并整理结果',
      ),
      _TemplateCardData(
        icon: Icons.install_desktop_outlined,
        title: '微信插件',
        subtitle: '安装并启用 OpenClaw 微信连接能力',
        prompt: '',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SearchField(hint: '搜索技能', onSubmitted: _prefillPrompt),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _prefillPrompt('帮我导入一个 OpenClaw 技能'),
              icon: const Icon(Icons.add),
              label: const Text('添加技能'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          children: const [
            Chip(label: Text('技能市场')),
            Chip(label: Text('已安装 14')),
            Chip(label: Text('套件')),
          ],
        ),
        const SizedBox(height: 20),
        _ResponsiveCardGrid(
          children: skills.map((item) {
            final isPlugin = item.title == '微信插件';
            return _ActionCard(
              icon: item.icon,
              title: item.title,
              subtitle: item.subtitle,
              actionLabel: isPlugin ? '安装' : '调用',
              busy: isPlugin && _isRunningAction,
              onTap: isPlugin
                  ? () => _runOpenClawAction(
                      '安装微信插件',
                      OpenClawRuntime.instance.installWeChatPlugin,
                    )
                  : () => _prefillPrompt(item.prompt),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildConnectorsMarket() {
    final status = _desktopStatus;
    final screenGranted = status?.screenRecordingGranted == true;
    final accessibilityGranted = status?.accessibilityGranted == true;

    final connectors = [
      _ConnectorCardData(
        icon: Icons.chat_bubble_outline,
        title: '微信',
        subtitle: '扫码登录后，从微信给桌面端发消息',
        state: '连接',
        onTap: () =>
            _runOpenClawAction('微信扫码登录', OpenClawRuntime.instance.loginWeChat),
      ),
      _ConnectorCardData(
        icon: Icons.qr_code_2_outlined,
        title: '移动端',
        subtitle: '生成远程配对码，手机从公网连接桌面端',
        state: _remoteGatewayUrl.trim().isEmpty ? '配置' : '配对',
        onTap: _createMobilePairingCode,
      ),
      _ConnectorCardData(
        icon: Icons.travel_explore_outlined,
        title: '远程入口',
        subtitle: _remoteGatewayUrl.trim().isEmpty
            ? '未配置 wss:// 入口'
            : _remoteGatewayUrl,
        state: '编辑',
        onTap: _editRemoteGatewayUrl,
      ),
      _ConnectorCardData(
        icon: Icons.desktop_mac_outlined,
        title: '桌面控制',
        subtitle: status?.message ?? '本机桌面工具桥尚未检测',
        state: status?.bridgeRunning == true ? '已就绪' : '启动',
        onTap: () => DesktopControlBridge.instance.ensureStarted().then(
          (_) => _loadRuntimeStatus(probeOpenClaw: true),
        ),
      ),
      _ConnectorCardData(
        icon: Icons.admin_panel_settings_outlined,
        title: '系统权限',
        subtitle:
            '屏幕录制 ${screenGranted ? '已授权' : '未授权'} · 辅助功能 ${accessibilityGranted ? '已授权' : '未授权'}',
        state: screenGranted && accessibilityGranted ? '已授权' : '申请',
        onTap: () => _requestDesktopPermission(screenRecording: !screenGranted),
      ),
      _ConnectorCardData(
        icon: Icons.public,
        title: 'Chrome',
        subtitle: status?.chrome.message ?? '浏览器连接器尚未检测',
        state: status?.chrome.connected == true ? '已连接' : '连接',
        onTap: _prepareChromeConnector,
      ),
      _ConnectorCardData(
        icon: Icons.forum_outlined,
        title: '渠道状态',
        subtitle: '检查微信、小程序、移动端渠道',
        state: '检测',
        onTap: () => _runOpenClawAction(
          'OpenClaw 渠道状态',
          OpenClawRuntime.instance.inspectChannels,
        ),
      ),
      _ConnectorCardData(
        icon: Icons.article_outlined,
        title: '诊断日志',
        subtitle: '复制或打开本机运行日志',
        state: '复制',
        onTap: _copyDiagnosticLogTail,
        secondaryTap: _openDiagnosticLogLocation,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusStrip(),
        const SizedBox(height: 22),
        _ResponsiveCardGrid(
          minWidth: 300,
          children: connectors
              .map(
                (item) => _ConnectorCard(
                  data: item,
                  busy:
                      _isRunningAction ||
                      _isPreparingConnector ||
                      _isRestarting,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildAutomationView() {
    final templates = [
      _TemplateCardData(
        icon: Icons.newspaper_outlined,
        title: '每日 AI 新闻推送',
        subtitle: '筛选 3-5 条 AI coding 与智能体动态',
        prompt: '创建每日 AI 新闻推送自动化',
      ),
      _TemplateCardData(
        icon: Icons.summarize_outlined,
        title: '每周工作周报',
        subtitle: '汇总 PR、Issue、产物与待关注事项',
        prompt: '创建每周工作周报自动化',
      ),
      _TemplateCardData(
        icon: Icons.edit_calendar_outlined,
        title: '会议前准备',
        subtitle: '整理议题、目标、待确认问题',
        prompt: '创建会议前准备提醒',
      ),
      _TemplateCardData(
        icon: Icons.chat_bubble_outline,
        title: '微信待命',
        subtitle: '从微信收到消息时唤醒桌面端执行',
        prompt: '创建微信待命自动化：收到微信消息后让桌面端执行任务',
      ),
      _TemplateCardData(
        icon: Icons.public,
        title: '发布前检查',
        subtitle: '自动检查链接、标题、素材、截图',
        prompt: '创建发布前检查自动化',
      ),
      _TemplateCardData(
        icon: Icons.health_and_safety_outlined,
        title: '本机健康巡检',
        subtitle: '检查 OpenClaw、连接器、权限和日志',
        prompt: '创建本机 OpenClaw 健康巡检自动化',
      ),
    ];

    return _WorkbenchPage(
      title: '自动化',
      subtitle: '把重复任务交给 OpenClaw 定时或远程触发',
      controller: _contentScrollControllers[_WorkbenchSection.automation],
      actions: [
        FilledButton.icon(
          onPressed: () => _prefillPrompt('添加一个新的 OpenClaw 自动化任务'),
          icon: const Icon(Icons.add),
          label: const Text('添加'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('从模板入手'),
          const SizedBox(height: 12),
          _ResponsiveCardGrid(
            children: templates
                .map(
                  (item) => _ActionCard(
                    icon: item.icon,
                    title: item.title,
                    subtitle: item.subtitle,
                    onTap: () => _prefillPrompt(item.prompt),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEAEAE8))),
      ),
      child: Row(
        children: [
          const Text('已连接：', style: TextStyle(color: Color(0xFF8A8A87))),
          _ConnectionPill(
            icon: Icons.desktop_mac_outlined,
            label: '本机桌面',
            active: _desktopStatus?.bridgeRunning == true,
          ),
          _ConnectionPill(
            icon: Icons.chat_bubble_outline,
            label: '微信',
            active: _remoteGatewayUrl.trim().isNotEmpty,
          ),
          _ConnectionPill(
            icon: Icons.phone_iphone,
            label: '移动端',
            active: _remoteGatewayUrl.trim().isNotEmpty,
          ),
          const Spacer(),
          IconButton(
            tooltip: '搜索',
            onPressed: () => _prefillPrompt('在当前对话里搜索：'),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: '分享任务',
            onPressed: _createMobilePairingCode,
            icon: const Icon(Icons.ios_share),
          ),
          IconButton(
            tooltip: '显示详情',
            onPressed: _refreshRuntimeStatus,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    final canSend = _promptController.text.trim().isNotEmpty && !_isSending;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E4E2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _promptController,
            minLines: 2,
            maxLines: 5,
            enabled: !_isSending,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(fontSize: 15, height: 1.35),
            decoration: const InputDecoration(
              hintText: '今天帮你做些什么？ @ 引用对话文件，/ 调用技能与指令',
              border: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(18, 16, 18, 10),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const Divider(height: 1, color: Color(0xFFEDEDEB)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ComposerMenuButton(
                  icon: Icons.auto_fix_high_outlined,
                  label: 'Craft',
                  onTap: () => _prefillPrompt('帮我把这个任务重写成更清晰的执行指令：'),
                ),
                _buildModeMenu(),
                _buildSkillsMenu(),
                _buildConnectMenu(),
                _buildPermissionMenu(),
                _ComposerMenuButton(
                  icon: Icons.folder_outlined,
                  label: '选择工作空间',
                  onTap: () => _prefillPrompt('把当前目录作为工作空间，帮我规划接下来的操作'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '添加',
                  onPressed: _isSending ? null : _createMobilePairingCode,
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  tooltip: '工具',
                  onPressed: () => _selectSection(
                    _WorkbenchSection.experts,
                    marketTab: _MarketTab.skills,
                  ),
                  icon: const Icon(Icons.auto_awesome_outlined),
                ),
                IconButton(
                  tooltip: _isSending ? '停止' : '发送',
                  onPressed: _isSending
                      ? _stopGeneration
                      : canSend
                      ? _sendPrompt
                      : null,
                  icon: Icon(_isSending ? Icons.stop : Icons.arrow_upward),
                  style: IconButton.styleFrom(
                    backgroundColor: canSend || _isSending
                        ? const Color(0xFF1F1F1F)
                        : const Color(0xFFD6D6D2),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeMenu() {
    return PopupMenuButton<String>(
      tooltip: '模型模式',
      onSelected: (value) => setState(() => _mode = value),
      itemBuilder: (context) => const [
        PopupMenuItem(value: '自动', child: Text('自动')),
        PopupMenuItem(value: '本机全能', child: Text('本机全能')),
        PopupMenuItem(value: '远程接管', child: Text('远程接管')),
        PopupMenuItem(value: '微信待命', child: Text('微信待命')),
        PopupMenuDivider(),
        PopupMenuItem(value: '自定义模型', child: Text('+ 配置自定义模型')),
      ],
      child: _ComposerMenuButton(
        icon: Icons.psychology_alt_outlined,
        label: _mode,
      ),
    );
  }

  Widget _buildSkillsMenu() {
    return PopupMenuButton<String>(
      tooltip: '技能',
      onSelected: _handleSkillSelection,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'find', child: Text('find-skills')),
        PopupMenuItem(value: 'publish', child: Text('media-auto-publisher')),
        PopupMenuItem(
          value: 'wechat-draft',
          child: Text('wechat-draft-publisher'),
        ),
        PopupMenuItem(value: 'browser', child: Text('Web Access（浏览器自动化）')),
        PopupMenuItem(value: 'doc', child: Text('PDF / Word / Excel')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'import', child: Text('导入技能')),
      ],
      child: const _ComposerMenuButton(
        icon: Icons.handyman_outlined,
        label: '技能',
      ),
    );
  }

  Widget _buildConnectMenu() {
    return PopupMenuButton<String>(
      tooltip: '连应用',
      onSelected: _handleConnectorSelection,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'wechat', child: Text('微信')),
        PopupMenuItem(value: 'mobile', child: Text('移动端')),
        PopupMenuItem(value: 'chrome', child: Text('Chrome')),
        PopupMenuItem(value: 'desktop', child: Text('本机桌面')),
        PopupMenuItem(value: 'remote', child: Text('远程入口')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'more', child: Text('更多连接器')),
      ],
      child: const _ComposerMenuButton(icon: Icons.link_outlined, label: '连应用'),
    );
  }

  Widget _buildPermissionMenu() {
    return PopupMenuButton<String>(
      tooltip: '权限',
      onSelected: (value) {
        setState(() => _permissionMode = value);
        if (value == '完全访问权限') {
          unawaited(_loadRuntimeStatus(probeOpenClaw: true));
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: '默认权限', child: Text('默认权限')),
        PopupMenuItem(value: '完全访问权限', child: Text('完全访问权限')),
      ],
      child: _ComposerMenuButton(
        icon: Icons.verified_user_outlined,
        label: _permissionMode,
      ),
    );
  }

  void _handleSkillSelection(String value) {
    switch (value) {
      case 'find':
        _prefillPrompt('帮我查找并安装适合当前任务的技能');
        break;
      case 'publish':
        _prefillPrompt('使用 media-auto-publisher 发布这篇内容');
        break;
      case 'wechat-draft':
        _prefillPrompt('使用 wechat-draft-publisher 上传微信公众号草稿');
        break;
      case 'browser':
        _prefillPrompt('使用浏览器自动化打开网页、截图并提取信息');
        break;
      case 'doc':
        _prefillPrompt('帮我处理 PDF/Word/Excel 文件并生成结果');
        break;
      case 'import':
        _prefillPrompt('帮我导入一个 OpenClaw 技能');
        break;
    }
  }

  void _handleConnectorSelection(String value) {
    switch (value) {
      case 'wechat':
        unawaited(
          _runOpenClawAction('微信扫码登录', OpenClawRuntime.instance.loginWeChat),
        );
        break;
      case 'mobile':
        unawaited(_createMobilePairingCode());
        break;
      case 'chrome':
        unawaited(_prepareChromeConnector());
        break;
      case 'desktop':
        unawaited(
          DesktopControlBridge.instance.ensureStarted().then(
            (_) => _loadRuntimeStatus(probeOpenClaw: true),
          ),
        );
        break;
      case 'remote':
        unawaited(_editRemoteGatewayUrl());
        break;
      case 'more':
        _selectSection(
          _WorkbenchSection.experts,
          marketTab: _MarketTab.connectors,
        );
        break;
    }
  }

  void _handleMoreSelection(String value) {
    switch (value) {
      case 'files':
        _prefillPrompt('帮我查看和整理本机文件');
        break;
      case 'docs':
        _prefillPrompt('连接腾讯文档并整理文档内容');
        break;
      case 'knowledge':
        _prefillPrompt('从知识库里查找相关资料');
        break;
      case 'ideas':
        _prefillPrompt('帮我整理灵感并转成可执行任务');
        break;
    }
  }

  Widget _buildActivityNotice() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF7F4),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3EFEB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00C49A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.rocket_launch,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '远程通知',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Icon(Icons.close, size: 16, color: Color(0xFF777777)),
                ],
              ),
              const SizedBox(height: 10),
              const Text('移动端或微信发来的任务，会在这里唤醒本机 OpenClaw。'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _createMobilePairingCode,
                  child: const Text('查看配对'),
                ),
              ),
            ],
          ),
        ),
        const Positioned(
          right: 16,
          bottom: -38,
          child: CircleAvatar(
            radius: 31,
            backgroundColor: Color(0xFF111111),
            child: Icon(Icons.smart_toy, color: Color(0xFF00E0B8), size: 31),
          ),
        ),
      ],
    );
  }

  Widget _buildGrowthButton() {
    return FilledButton.icon(
      onPressed: _createMobilePairingCode,
      icon: const Icon(Icons.rocket_launch, size: 18),
      label: const Text('来连接移动端'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF151515),
        side: const BorderSide(color: Color(0xFFE5E5E1)),
      ),
    );
  }

  Widget _buildStatusStrip() {
    final openClawHealthy = _openClawStatus?.isHealthy == true;
    final bridgeHealthy = _desktopStatus?.bridgeRunning == true;
    final remoteReady = _remoteGatewayUrl.trim().isNotEmpty;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatusPill(
          icon: Icons.hub_outlined,
          label: _isLoadingStatus
              ? 'OpenClaw 检测中'
              : openClawHealthy
              ? 'OpenClaw 运行中'
              : _openClawStatus?.label ?? 'OpenClaw 未检测',
          active: openClawHealthy,
          onTap: _refreshRuntimeStatus,
        ),
        _StatusPill(
          icon: Icons.desktop_mac_outlined,
          label: bridgeHealthy ? '桌面工具已连接' : '桌面工具待启动',
          active: bridgeHealthy,
          onTap: () => DesktopControlBridge.instance.ensureStarted().then(
            (_) => _loadRuntimeStatus(probeOpenClaw: true),
          ),
        ),
        _StatusPill(
          icon: Icons.qr_code_2_outlined,
          label: remoteReady ? '远程入口已配置' : '远程入口未配置',
          active: remoteReady,
          onTap: _editRemoteGatewayUrl,
        ),
        _StatusPill(
          icon: Icons.restart_alt,
          label: _isRestarting ? '重启中' : '重启本机 AI',
          active: openClawHealthy,
          onTap: _restartOpenClaw,
        ),
      ],
    );
  }

  String _sectionLabel(_WorkbenchSection section) {
    return switch (section) {
      _WorkbenchSection.newTask => '新建任务',
      _WorkbenchSection.assistant => '助理',
      _WorkbenchSection.projects => '项目',
      _WorkbenchSection.experts => '专家',
      _WorkbenchSection.automation => '自动化',
    };
  }

  String _marketTabLabel(_MarketTab tab) {
    return switch (tab) {
      _MarketTab.experts => '专家',
      _MarketTab.skills => '技能',
      _MarketTab.connectors => '连接器',
    };
  }
}

class _WorkbenchMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final String? status;

  const _WorkbenchMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.status,
  });
}

class _TopSectionButton extends StatelessWidget {
  final Widget label;
  final bool selected;
  final VoidCallback onTap;

  const _TopSectionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF111524) : const Color(0xFF171726),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check, size: 15, color: Colors.white),
                const SizedBox(width: 6),
              ],
              DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
                child: label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateCardData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String prompt;

  const _TemplateCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.prompt,
  });
}

class _ConnectorCardData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String state;
  final VoidCallback onTap;
  final VoidCallback? secondaryTap;

  const _ConnectorCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.onTap,
    this.secondaryTap,
  });
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final bool selected;
  final VoidCallback? onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    this.trailing,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? const Color(0xFFE0E0DE) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF30302F)),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: const Color(0xFF202020),
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: const TextStyle(
                      color: Color(0xFFB0B0AD),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarGroupTitle extends StatelessWidget {
  final String text;

  const _SidebarGroupTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF8C8C89),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _RecentTask extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _RecentTask({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF3D3D3B)),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '刚刚',
              style: TextStyle(color: Color(0xFFB2B2AF), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpaceItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SpaceItem({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.folder_outlined),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}

class _WorkbenchPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final ScrollController? controller;
  final List<Widget> actions;
  final Widget child;

  const _WorkbenchPage({
    required this.title,
    required this.subtitle,
    this.controller,
    this.actions = const [],
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: PageStorageKey('openclaw-workbench-page-$title'),
      controller: controller,
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF151515),
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF777772), fontSize: 14),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
        const SizedBox(height: 28),
        child,
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onSubmitted;

  const _SearchField({required this.hint, required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        onSubmitted: (value) {
          final text = value.trim();
          if (text.isNotEmpty) onSubmitted(text);
        },
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, size: 18),
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE4E4E2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE4E4E2)),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF1B1B1B),
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _ResponsiveCardGrid extends StatelessWidget {
  final List<Widget> children;
  final double minWidth;

  const _ResponsiveCardGrid({required this.children, this.minWidth = 280});

  @override
  Widget build(BuildContext context) {
    final available = MediaQuery.sizeOf(context).width - 72;
    final width = available < minWidth
        ? available.clamp(220, minWidth)
        : minWidth;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: children
          .map((child) => SizedBox(width: width.toDouble(), child: child))
          .toList(),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final bool busy;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel = '',
    this.busy = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE8E8E5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2EF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF3C3C3A)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF222222),
                            ),
                          ),
                        ),
                        if (busy)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (actionLabel.isNotEmpty)
                          Text(
                            actionLabel,
                            style: const TextStyle(
                              color: Color(0xFF777772),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF777772),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TintedSceneCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TintedSceneCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEAF8F2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 140),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDEFE8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF00A37E), size: 26),
              const SizedBox(height: 30),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF60605D)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: _ActionCard(
        icon: Icons.account_tree_outlined,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
      ),
    );
  }
}

class _ConnectorCard extends StatelessWidget {
  final _ConnectorCardData data;
  final bool busy;

  const _ConnectorCard({required this.data, required this.busy});

  @override
  Widget build(BuildContext context) {
    return _ActionCard(
      icon: data.icon,
      title: data.title,
      subtitle: data.subtitle,
      actionLabel: data.state,
      busy: busy,
      onTap: data.secondaryTap == null ? data.onTap : data.onTap,
    );
  }
}

class _PromptChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PromptChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: const Color(0xFF333333)),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE2E2DE)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w800),
    );
  }
}

class _ComposerMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ComposerMenuButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: const Color(0xFF444442)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Color(0xFF777772),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _ConnectionPill({
    required this.icon,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE7F7F1) : const Color(0xFFF2F2EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: active ? const Color(0xFF00A37E) : const Color(0xFF8A8A87),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        icon,
        size: 17,
        color: active ? const Color(0xFF00A37E) : Colors.orange.shade700,
      ),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: active ? const Color(0xFFD5EEE5) : const Color(0xFFF1D6B9),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _WorkbenchMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bg = isUser
        ? const Color(0xFF1F1F1F)
        : message.isError
        ? const Color(0xFFFFE9E9)
        : Colors.white;
    final fg = isUser ? Colors.white : const Color(0xFF202020);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUser ? const Color(0xFF1F1F1F) : const Color(0xFFE7E7E4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.status != null && message.status!.isNotEmpty) ...[
              Text(
                message.status!,
                style: TextStyle(
                  color: isUser ? Colors.white70 : AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
            ],
            MarkdownBody(
              data: message.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                    p: TextStyle(color: fg, fontSize: 15, height: 1.45),
                    code: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF202020),
                      backgroundColor: isUser
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0xFFF1F1EF),
                      fontFamily: 'monospace',
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
