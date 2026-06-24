import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config/app_config.dart';
import '../core/constants/country_servers.dart' as country_catalog;
import '../features/auth/application/auth_model.dart';
import '../features/flashcards/application/content_pipeline.dart';
import '../features/flashcards/application/flashcard_service.dart';
import '../features/flashcards/data/flashcard_repository.dart';
import '../features/flashcards/domain/flashcard_models.dart';
import '../features/flashcards/presentation/flashcard_study_screen.dart';
import '../models/file_transfer_model.dart'
    if (dart.library.html) '../models/file_transfer_model_web.dart';
import '../services/ai_backend_policy.dart';
import '../services/alipay_service.dart'
    if (dart.library.html) '../services/alipay_service_web.dart';
import '../services/app_settings.dart';
import '../services/dacheng_ai_service.dart';
import '../services/desktop_control/desktop_control_bridge.dart';
import '../services/desktop_control/desktop_control_models.dart';
import '../services/diagnostic_log_service.dart';
import '../services/dharma_publish_service.dart';
import '../services/inbound_share_service.dart';
import '../services/openclaw/openclaw_runtime.dart';
import 'dharma_publish_browser_screen.dart'
    if (dart.library.html) 'dharma_publish_browser_screen_web.dart';
import '../widgets/earth_globe_widget.dart';
import '../widgets/home_world_2d_widget.dart';
import '../widgets/scene_render_mode.dart';
import '../widgets/codex_desktop_chat_input.dart';
import 'leaderboard_screen.dart';
import '../core/design_system/app_theme.dart';
import '../services/apple_iap_service.dart'
    if (dart.library.html) '../services/apple_iap_service_web.dart';
import '../services/membership_service.dart';
import '../services/online_counter_service.dart';
import '../services/project_service.dart';
import '../widgets/auto_start_guide_dialog.dart';
import 'membership_screen.dart'
    if (dart.library.html) 'membership_screen_web.dart';

bool get _isNativeAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool get _isNativeIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
bool get _isNativeMacOs =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
bool get _isNativeMacOrWindows =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows);

class GlobeHomeScreen extends StatefulWidget {
  const GlobeHomeScreen({
    super.key,
    this.topBarTrailing,
    this.composerLeftInset,
  });

  final Widget? topBarTrailing;
  final double? composerLeftInset;

  @override
  State<GlobeHomeScreen> createState() => GlobeHomeScreenState();
}

class GlobeHomeScreenState extends State<GlobeHomeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<HomeWorld2DWidgetState> _world2DKey = GlobalKey();
  final GlobalKey<EarthGlobeWidgetState> _globe3DKey = GlobalKey();
  String _currentSendingCountry = '';
  final List<Map<String, dynamic>> _pendingBeams = [];
  bool _isGlobeLoaded = false;
  bool _isCallbackSetup = false;
  bool _isVisible = true;
  bool _isDharmaComposerMode = false;
  DharmaComposerTarget _dharmaComposerTarget = DharmaComposerTarget.global;
  final Set<DharmaPublishPlatform> _selectedPublishPlatforms = {
    DharmaPublishPlatform.xiaohongshu,
  };
  bool _showMaterialGallery = false;
  bool _isGlobalSendTimelineVisible = false;
  bool _isAiGenerating = false;
  bool _isPublishingDraft = false;
  bool _isFlashcardComposerMode = false;
  bool _isPreparingFlashcardContent = false;
  bool _isFlashcardGenerating = false;
  FlashcardCreationMode _flashcardMode = FlashcardCreationMode.randomCloze;
  PreparedContent? _activeFlashcardContent;
  String? _flashcardGenerationMessageId;
  String _streamingAiText = '';
  String _aiActivityText = '';
  SceneRenderMode _renderMode = SceneRenderMode.twoD;
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _homeChatScrollController = ScrollController();
  final List<_HomeChatMessage> _homeChatMessages = [];
  final List<_HomeConversation> _conversationHistory = [];
  StreamSubscription<DachengAiStreamEvent>? _aiStreamSubscription;
  StreamSubscription<FlashcardGenerationEvent>?
  _flashcardGenerationSubscription;
  final DachengAiService _dachengAiService = DachengAiService();
  final DharmaPublishService _dharmaPublishService = DharmaPublishService();
  late final FlashcardRepository _flashcardRepository;
  late final ContentPipeline _contentPipeline;
  late final FlashcardService _flashcardService;
  StreamSubscription<IncomingSharePayload>? _incomingShareSubscription;
  String? _lastIncomingShareFingerprint;
  String? _activeConversationId;
  int _aiRequestSerial = 0;
  int _flashcardRequestSerial = 0;
  final _onlineCounterService = OnlineCounterService();
  final _membershipService = MembershipService();
  final _alipayService = AlipayService();
  final _appleIapService = AppleIapService();
  bool _isOpenClawPanelLoading = false;
  bool _isRunningOpenClawAction = false;
  bool _isRestartingOpenClaw = false;
  bool _isPreparingChromeConnector = false;
  String _openClawRemoteGatewayUrl = '';
  String _openClawModeLabel = '自动';
  String _openClawPermissionLabel = '默认权限';
  OpenClawRuntimeStatus? _openClawStatus;
  DesktopControlBridgeStatus? _desktopControlStatus;
  List<DesktopControlPendingConfirmation> _desktopControlPending = const [];
  bool? _buddhaAssetUnlocked;
  bool _isPurchasingBuddhaAsset = false;
  DateTime? _sendStartedAt;
  String _activeSendTitle = '';
  String _activeSendRegion = '';
  String _selectedDesktopModelId = 'deepseek-chat';
  LocalProject? _selectedDesktopProject;
  List<CodexDesktopModelOption> _desktopModelOptions =
      CodexDesktopChatInput.defaultModelOptions;

  void setVisible(bool visible) {
    if (_isVisible == visible) return;
    _isVisible = visible;
    debugPrint('🌍 地球页面可见性变化: $visible');

    _syncActiveSceneVisibility();
    if (visible) {
      _playPendingBeams();
    }
  }

  bool _forceGlobeMode = false;
  void setGlobeMode(bool isGlobeMode) {
    if (_forceGlobeMode != isGlobeMode) {
      setState(() {
        _forceGlobeMode = isGlobeMode;
      });
    }
  }

  // ignore: unused_element
  bool get _canUseThreeDNow {
    final authModel = Provider.of<AuthModel?>(context, listen: false);
    return SceneRenderAccess.canUseThreeDFor(authModel);
  }

  bool get _isThreeDActiveNow {
    return _renderMode == SceneRenderMode.threeD;
  }

  void _syncActiveSceneVisibility() {
    final useThreeD = _isThreeDActiveNow;
    _world2DKey.currentState?.setRenderingPaused(!_isVisible || useThreeD);
    _globe3DKey.currentState?.setRenderingPaused(!_isVisible || !useThreeD);
  }

  bool _addTransferBeamToScene(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng, {
    Duration? duration,
    String? toLabel,
  }) {
    try {
      if (_isThreeDActiveNow) {
        final state = _globe3DKey.currentState;
        if (state == null) return false;
        state.addTransferBeam(
          fromLat,
          fromLng,
          toLat,
          toLng,
          duration: duration,
          toLabel: toLabel,
        );
        return true;
      }

      final state = _world2DKey.currentState;
      if (state == null) return false;
      state.addTransferBeam(
        fromLat,
        fromLng,
        toLat,
        toLng,
        duration: duration,
        toLabel: toLabel,
      );
      return true;
    } catch (e) {
      debugPrint('❌ 添加 2D/3D 轨迹失败: $e');
      return false;
    }
  }

  void _clearActiveSceneBeams() {
    _world2DKey.currentState?.clearBeams();
    _globe3DKey.currentState?.clearBeams();
  }

  void _toggleSceneRenderMode() {
    setState(() {
      _renderMode = _renderMode == SceneRenderMode.twoD
          ? SceneRenderMode.threeD
          : SceneRenderMode.twoD;
      _isCallbackSetup = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncActiveSceneVisibility();
      if (mounted) _setupTransferBeamCallback();
    });
  }

  @override
  void initState() {
    super.initState();
    _flashcardRepository = FlashcardRepository();
    _contentPipeline = ContentPipeline(repository: _flashcardRepository);
    _flashcardService = FlashcardService(
      repository: _flashcardRepository,
      aiService: _dachengAiService,
    );
    WidgetsBinding.instance.addObserver(this);
    _loadGlobe();
    _fetchInitialCount();
    unawaited(_loadDesktopModelOptions());
    InboundShareService.instance.start();
    _incomingShareSubscription = InboundShareService.instance.incomingShares
        .listen((payload) => unawaited(_handleIncomingShare(payload)));
    _onlineCounterService.startCountPolling('global_sending');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeInitialWebPrompt();
      unawaited(_loadRemoteConversations());
      unawaited(_refreshBuddhaAssetEntitlement());
      unawaited(_consumeInitialShare());
      unawaited(_loadOpenClawHomeStatus(probeOpenClaw: false));
    });
  }

  void _consumeInitialWebPrompt() {
    if (!kIsWeb) return;
    final prompt = Uri.base.queryParameters['prompt']?.trim();
    if (prompt == null || prompt.isEmpty) return;

    _prefillPrompt(prompt);

    final shouldAutoStart = Uri.base.queryParameters['autostart'] == '1';
    if (shouldAutoStart) {
      unawaited(_sendAiChatFromComposer());
    }
  }

  Future<void> _fetchInitialCount() async {
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      await _onlineCounterService.fetchCountForActivity('global_sending');
    } catch (e) {
      debugPrint('获取初始在线人数失败: $e');
    }
  }

  Future<void> _loadDesktopModelOptions() async {
    try {
      final authModel = Provider.of<AuthModel?>(context, listen: false);
      final models = await _dachengAiService.listModels(
        token: authModel?.authToken,
      );
      if (!mounted || models.isEmpty) return;
      final options = models.map(_desktopModelOptionFromBackend).toList();
      setState(() {
        _desktopModelOptions = options;
        if (!options.any((option) => option.id == _selectedDesktopModelId)) {
          _selectedDesktopModelId = options.first.id;
        }
      });
    } catch (e) {
      debugPrint('加载 DeepSeek 模型列表失败，使用默认模型: $e');
    }
  }

  CodexDesktopModelOption _desktopModelOptionFromBackend(
    DachengAiModelSummary model,
  ) {
    final id = model.id.trim();
    final lower = id.toLowerCase();
    final isReasoner = lower.contains('reasoner') || lower.contains('r1');
    return CodexDesktopModelOption(
      id: id,
      label: model.label.trim().isEmpty ? id : model.label.trim(),
      shortLabel: isReasoner ? 'Reasoner' : 'Chat',
      subtitle: isReasoner ? '推理、规划与复杂项目任务' : '通用对话、写作与工具调用',
      icon: isReasoner ? Icons.psychology_alt_outlined : Icons.bolt_outlined,
    );
  }

  Future<void> _loadRemoteConversations() async {
    try {
      final authModel = Provider.of<AuthModel?>(context, listen: false);
      final summaries = await _dachengAiService.listConversations(
        token: authModel?.authToken,
        username: authModel?.currentUser?.username,
        isMember: authModel?.hasPermission('premium') ?? false,
      );
      if (!mounted || summaries.isEmpty) return;
      setState(() {
        _conversationHistory
          ..clear()
          ..addAll(
            summaries.map(
              (summary) => _HomeConversation(
                id: summary.id,
                title: summary.title,
                messages: const [],
                updatedAt: summary.updatedAt,
              ),
            ),
          );
      });
    } catch (e) {
      debugPrint('加载大乘 AI 历史失败: $e');
    }
  }

  Future<void> _refreshBuddhaAssetEntitlement() async {
    try {
      final authModel = Provider.of<AuthModel?>(context, listen: false);
      if (authModel == null || !authModel.isLoggedIn) return;
      await _checkBuddhaAssetEntitlement(authModel);
    } catch (e) {
      debugPrint('刷新 3D 佛像素材解锁状态失败: $e');
    }
  }

  void _loadGlobe() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        try {
          setState(() => _isGlobeLoaded = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            debugPrint('🎬 地球组件加载完成');
            _setupTransferBeamCallback();
          });
        } catch (e) {
          debugPrint('⚠️ 地球组件加载失败: $e');
          if (mounted) {
            setState(() => _isGlobeLoaded = true);
          }
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_isGlobeLoaded) {
        _loadGlobe();
      } else {
        _isCallbackSetup = false;
        _setupTransferBeamCallback();
      }
      unawaited(_consumeInitialShare());
    }
  }

  @override
  void didUpdateWidget(GlobeHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _isCallbackSetup = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupTransferBeamCallback();
    });
  }

  @override
  void dispose() {
    try {
      Provider.of<FileTransferModel>(
        context,
        listen: false,
      ).setTransferBeamCallback(null);
    } catch (_) {}
    _onlineCounterService.dispose();
    _incomingShareSubscription?.cancel();
    _aiStreamSubscription?.cancel();
    _flashcardGenerationSubscription?.cancel();
    _chatInputController.dispose();
    _homeChatScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupTransferBeamCallback() {
    if (_isCallbackSetup &&
        (_world2DKey.currentState != null ||
            _globe3DKey.currentState != null)) {
      return;
    }

    final model = Provider.of<FileTransferModel>(context, listen: false);
    model.setTransferBeamCallback((
      fromLat,
      fromLng,
      toLat,
      toLng, {
      String? fromLabel,
      String? toLabel,
      Duration? displayDuration,
    }) {
      if (toLabel != null && mounted) {
        setState(() {
          _currentSendingCountry = toLabel;
        });
      }

      final added =
          _isVisible &&
          _addTransferBeamToScene(
            fromLat,
            fromLng,
            toLat,
            toLng,
            duration: displayDuration ?? const Duration(milliseconds: 800),
            toLabel: toLabel,
          );

      if (!added) {
        _pendingBeams.add({
          'fromLat': fromLat,
          'fromLng': fromLng,
          'toLat': toLat,
          'toLng': toLng,
          'toLabel': toLabel,
        });
        if (_pendingBeams.length > 20) {
          _pendingBeams.removeAt(0);
        }
      }
    });

    _isCallbackSetup = true;
    _playPendingBeams();
  }

  void _playPendingBeams() {
    if (_pendingBeams.isEmpty) return;
    if (!_isVisible) return;

    final hasScene = _isThreeDActiveNow
        ? _globe3DKey.currentState != null
        : _world2DKey.currentState != null;
    if (!hasScene) {
      Future.delayed(const Duration(milliseconds: 500), _playPendingBeams);
      return;
    }

    for (final beam in _pendingBeams) {
      final added = _addTransferBeamToScene(
        beam['fromLat'] as double,
        beam['fromLng'] as double,
        beam['toLat'] as double,
        beam['toLng'] as double,
        duration: const Duration(seconds: 3),
        toLabel: beam['toLabel'] as String?,
      );
      if (!added) {
        debugPrint('❌ 播放缓存目标点失败');
      }
    }
    _pendingBeams.clear();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authModel = Provider.of<AuthModel?>(context);

    if (!_isCallbackSetup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupTransferBeamCallback();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncActiveSceneVisibility();
      if (mounted) _playPendingBeams();
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawerScrimColor: Colors.black.withValues(alpha: 0.58),
      drawer: _buildConversationDrawer(),
      body: Stack(
        children: [
          _buildHomeBackground(),
          SafeArea(
            child: Consumer<FileTransferModel>(
              builder: (context, model, _) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final useDesktopWorkbench =
                        _isNativeMacOrWindows && constraints.maxWidth >= 920;
                    if (useDesktopWorkbench) {
                      return _buildDesktopHomeShell(context, model, authModel);
                    }

                    return Column(
                      children: [
                        _buildTopBar(authModel),
                        Expanded(
                          child: _buildHomeBody(context, model, authModel),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            widget.composerLeftInset ?? 18,
                            8,
                            18,
                            16,
                          ),
                          child: _buildChatComposer(context, model),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHomeShell(
    BuildContext context,
    FileTransferModel model,
    AuthModel? authModel,
  ) {
    final bool isEmpty = _homeChatMessages.isEmpty && !_forceGlobeMode;

    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        children: [
          _buildDesktopTopBar(),
          if (isEmpty)
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '海纳法流，普布十方',
                        style: TextStyle(
                          color: Color(0xFFE8BD6B),
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '您可以通过随心输入来查找资源、下载并启动全球法布施',
                        style: TextStyle(
                          color: Color(0xFF8A99AD),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildDesktopChatComposer(context, model),
                      const SizedBox(
                        height: 100,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Expanded(
              child: _buildDesktopWorkspace(context, model, authModel),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 8, 34, 26),
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: _buildDesktopChatComposer(context, model),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton.icon(
            onPressed: _createOpenClawHomeMobilePairingCode,
            icon: const Icon(Icons.rocket_launch, size: 18),
            label: const Text('来连接移动端'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF202124),
              side: const BorderSide(color: Color(0xFFE5E5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopWorkspace(
    BuildContext context,
    FileTransferModel model,
    AuthModel? authModel,
  ) {
    final showChat =
        _homeChatMessages.isNotEmpty ||
        _isAiGenerating ||
        _shouldShowGlobalSendProcess(model);

    if (showChat) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: _buildChatTimeline(model, light: true),
        ),
      );
    }

    return _buildDesktopIntroPanel(authModel);
  }

  Widget _buildDesktopIntroPanel(AuthModel? authModel) {
    final displayName = authModel?.currentUser?.displayName.trim() ?? '';
    final greeting = displayName.isEmpty ? '大乘' : 'Hi, $displayName';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        return Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(32, compact ? 24 : 54, 32, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          color: const Color(0xFF17181A),
                          fontSize: compact ? 42 : 50,
                          fontWeight: FontWeight.w900,
                          height: 1.02,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '你的本地 OpenClaw 超能力',
                        style: TextStyle(
                          color: const Color(0xFF17181A),
                          fontSize: compact ? 35 : 44,
                          fontWeight: FontWeight.w900,
                          height: 1.06,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _DesktopModeChip(
                            icon: Icons.coffee_outlined,
                            label: '日常办公',
                            selected: _openClawModeLabel == '自动',
                            onTap: () =>
                                setState(() => _openClawModeLabel = '自动'),
                          ),
                          _DesktopModeChip(
                            icon: Icons.code,
                            label: '代码开发',
                            selected: _openClawModeLabel == '本机全能',
                            onTap: () =>
                                setState(() => _openClawModeLabel = '本机全能'),
                          ),
                          _DesktopModeChip(
                            icon: Icons.palette_outlined,
                            label: '设计创意',
                            selected: _openClawModeLabel == '远程接管',
                            onTap: () =>
                                setState(() => _openClawModeLabel = '远程接管'),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 36 : 64),
                      Wrap(
                        spacing: 10,
                        runSpacing: 12,
                        children: [
                          _DesktopPromptPill(
                            icon: Icons.description_outlined,
                            label: '文档处理',
                            onTap: () => _prefillPrompt('帮我把这份文档整理成清晰摘要和行动清单'),
                          ),
                          _DesktopPromptPill(
                            icon: Icons.public_outlined,
                            label: '全球法布施',
                            onTap: () => _prefillPrompt('帮我策划一次全球法布施发布任务'),
                          ),
                          _DesktopPromptPill(
                            icon: Icons.chat_bubble_outline,
                            label: '微信远程',
                            onTap: () => _prefillPrompt('帮我检查微信和移动端远程控制是否可用'),
                          ),
                          _DesktopPromptPill(
                            icon: Icons.apps_outlined,
                            label: '更多',
                            onTap: () =>
                                _prefillPrompt('帮我列出当前可用的专家、技能、连接器和自动化能力'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildDesktopStatusStrip(),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 52,
              top: compact ? 60 : 124,
              child: _buildDesktopRemoteNotice(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopRemoteNotice() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 286),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF7F4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3EFEB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
                    style: TextStyle(
                      color: Color(0xFF303437),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _refreshOpenClawHomeStatus,
                  child: const Icon(
                    Icons.refresh,
                    size: 16,
                    color: Color(0xFF777777),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _openClawRemoteGatewayUrl.trim().isEmpty
                  ? '配置公网入口后，移动端或微信发来的任务会唤醒这台电脑。'
                  : '移动端或微信已可通过远程入口唤醒本机 OpenClaw。',
              style: const TextStyle(
                color: Color(0xFF4C5555),
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _createOpenClawHomeMobilePairingCode,
                child: const Text('查看配对'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopStatusStrip() {
    final openClawHealthy = _openClawStatus?.isHealthy == true;
    final bridgeReady = _desktopControlStatus?.bridgeRunning == true;
    final remoteReady = _openClawRemoteGatewayUrl.trim().isNotEmpty;
    final chromeReady = _desktopControlStatus?.chrome.connected == true;
    final pending = _desktopControlPending.isEmpty
        ? null
        : _desktopControlPending.first;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _DesktopStatusPill(
          icon: Icons.hub_outlined,
          label: _isOpenClawPanelLoading
              ? 'OpenClaw 检测中'
              : openClawHealthy
              ? 'OpenClaw 运行中'
              : _openClawStatus?.label ?? 'OpenClaw 未检测',
          active: openClawHealthy,
          onTap: _refreshOpenClawHomeStatus,
        ),
        _DesktopStatusPill(
          icon: Icons.desktop_mac_outlined,
          label: bridgeReady ? '桌面工具已连接' : '桌面工具待启动',
          active: bridgeReady,
          onTap: _startDesktopBridgeFromHome,
        ),
        _DesktopStatusPill(
          icon: Icons.chat_bubble_outline,
          label: remoteReady ? '微信/移动端待命' : '远程未配置',
          active: remoteReady,
          onTap: _createOpenClawHomeMobilePairingCode,
        ),
        _DesktopStatusPill(
          icon: Icons.public,
          label: chromeReady ? 'Chrome 已连接' : 'Chrome 连接器',
          active: chromeReady,
          onTap: _prepareHomeChromeConnector,
        ),
        if (pending != null)
          _DesktopPendingActionPill(
            summary: pending.summary,
            onApprove: () => _approveHomeDesktopControlRequest(pending.id),
            onReject: () => _rejectHomeDesktopControlRequest(pending.id),
          ),
      ],
    );
  }

  Widget _buildHomeBackground() {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Image.asset(
              'assets/images/home_world_lightfield.webp',
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.18),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xAA071828), Color(0xEE07090B)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(AuthModel? authModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: '对话',
                  onPressed: () => Scaffold.of(buttonContext).openDrawer(),
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.24),
                    fixedSize: const Size(46, 46),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '大乘',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (AiBackendPolicy.isDesktopNative) _buildAiBackendBadge(),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child:
                  widget.topBarTrailing ??
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '排行榜',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LeaderboardScreen(),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.leaderboard_rounded,
                          color: Colors.white70,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.2),
                          fixedSize: const Size(42, 42),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildAvatar(authModel),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiBackendBadge() {
    final authModel = Provider.of<AuthModel?>(context, listen: false);
    return FutureBuilder<String>(
      future: AiBackendPolicy.activeBackendLabel(
        isMember: authModel?.hasPermission('premium') ?? false,
      ),
      builder: (context, snapshot) {
        final label = snapshot.data ?? '本机 OpenClaw';
        final isLocal = label.contains('OpenClaw');
        return Container(
          margin: const EdgeInsets.only(top: 1),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: (isLocal ? Colors.greenAccent : Colors.blueAccent)
                .withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(
            isLocal ? '本机 OpenClaw' : '云端 API',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              height: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(AuthModel? authModel) {
    final user = authModel?.currentUser;
    final avatar = user?.avatar?.trim();
    final displayName = user?.displayName.trim() ?? '';
    final initial = displayName.isNotEmpty ? displayName.substring(0, 1) : '灵';

    return CircleAvatar(
      radius: 22,
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.24),
      backgroundImage:
          avatar != null &&
              (avatar.startsWith('http://') || avatar.startsWith('https://'))
          ? NetworkImage(avatar)
          : null,
      child: avatar == null || avatar.isEmpty
          ? Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }

  Widget _buildConversationDrawer() {
    final drawerWidth = (MediaQuery.sizeOf(context).width * 0.78)
        .clamp(292.0, 360.0)
        .toDouble();

    return Drawer(
      width: drawerWidth,
      backgroundColor: const Color(0xFF1E2024),
      child: Consumer<FileTransferModel>(
        builder: (context, model, _) {
          return _buildConversationSidebar(model, embedded: false);
        },
      ),
    );
  }

  Widget _buildConversationSidebar(
    FileTransferModel model, {
    required bool embedded,
  }) {
    final currentTitle = _conversationTitleFrom(_homeChatMessages);
    final authModel = Provider.of<AuthModel?>(context, listen: false);
    final displayName = authModel?.currentUser?.displayName.trim() ?? '';
    final userName = displayName.isNotEmpty
        ? displayName
        : authModel?.currentUser?.username ?? '大乘用户';
    final background = const Color(0xFF1E2024);
    final primaryText = Colors.white;
    final secondaryText = Colors.white54;
    final buttonBackground = const Color(0xFF30343A);
    final isBusy = _isAiGenerating;

    return Container(
      width: embedded ? 286 : null,
      decoration: BoxDecoration(
        color: background,
        border: embedded
            ? const Border(right: BorderSide(color: Color(0xFF2D3139)))
            : null,
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            embedded ? 16 : 18,
            18,
            embedded ? 16 : 18,
            18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '大乘',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: embedded ? 18 : 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '搜索',
                    onPressed: () => _prefillPrompt('搜索当前对话、本机文件和项目资料：'),
                    icon: Icon(Icons.search, color: secondaryText),
                  ),
                  IconButton(
                    tooltip: embedded ? '检测' : '关闭',
                    onPressed: embedded
                        ? _refreshOpenClawHomeStatus
                        : () => Navigator.maybePop(context),
                    icon: Icon(
                      embedded ? Icons.filter_alt_outlined : Icons.close,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isBusy ? null : () => _startNewConversation(model),
                  icon: const Icon(Icons.add_comment_outlined, size: 20),
                  label: const Text('新建任务'),
                  style: FilledButton.styleFrom(
                    backgroundColor: buttonBackground,
                    disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                    foregroundColor: primaryText,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildSidebarActionTile(
                icon: Icons.smart_toy_outlined,
                label: '助理',
                embedded: false,
                onTap: () => _prefillPrompt('让本机 OpenClaw 助理接手：'),
              ),
              _buildSidebarActionTile(
                icon: Icons.account_tree_outlined,
                label: '项目',
                embedded: false,
                onTap: () => _prefillPrompt('新建一个本机 OpenClaw 项目，目标是：'),
              ),
              _buildSidebarActionTile(
                icon: Icons.hub_outlined,
                label: '专家',
                trailing: '技能·连接器',
                embedded: false,
                onTap: () => _prefillPrompt('召唤适合当前任务的专家 and 技能：'),
              ),
              _buildSidebarActionTile(
                icon: Icons.alarm_on_outlined,
                label: '自动化',
                embedded: false,
                onTap: () => _prefillPrompt('创建一个 OpenClaw 自动化任务：'),
              ),
              _buildSidebarActionTile(
                icon: Icons.apps_outlined,
                label: '更多',
                trailing: '资料库·灵感',
                embedded: false,
                onTap: () => _prefillPrompt('帮我列出可用的资料库、灵感、技能和连接器'),
              ),
              const SizedBox(height: 22),
              _DrawerSectionLabel('任务', light: false),
              if (_homeChatMessages.isNotEmpty) ...[
                _ConversationTile(
                  title: currentTitle,
                  selected: true,
                  running: _shouldShowGlobalSendProcess(model),
                  light: false,
                  onTap: () {
                    if (!embedded) Navigator.maybePop(context);
                  },
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: _conversationHistory.isEmpty
                    ? Center(
                        child: Text(
                          '没有更多内容啦',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _conversationHistory.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final conversation = _conversationHistory[index];
                          return _ConversationTile(
                            title: conversation.title,
                            selected: false,
                            running: conversation.isGlobalSendRunning,
                            light: false,
                            onTap: isBusy
                                ? null
                                : () => _openConversation(conversation),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 14),
              _DrawerSectionLabel('空间', light: false),
              _buildSidebarSpaceTile(
                icon: Icons.folder_outlined,
                title: '本机电脑',
                subtitle: '浏览器、文件、桌面',
                embedded: false,
                onTap: _startDesktopBridgeFromHome,
              ),
              _buildSidebarSpaceTile(
                icon: Icons.chat_bubble_outline,
                title: '微信远程',
                subtitle: _openClawRemoteGatewayUrl.trim().isEmpty
                    ? '待配置'
                    : '已配置',
                embedded: false,
                onTap: _createOpenClawHomeMobilePairingCode,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFF00B894),
                    child: Icon(Icons.self_improvement, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '移动端配对',
                    onPressed: _isRunningOpenClawAction
                        ? null
                        : _createOpenClawHomeMobilePairingCode,
                    icon: Icon(Icons.qr_code_2_outlined, color: secondaryText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarActionTile({
    required IconData icon,
    required String label,
    required bool embedded,
    required VoidCallback onTap,
    String? trailing,
  }) {
    final foreground = embedded ? const Color(0xFF252729) : Colors.white70;
    final muted = embedded ? const Color(0xFF9EA1A3) : Colors.white38;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: foreground, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarSpaceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool embedded,
    required VoidCallback onTap,
  }) {
    final foreground = embedded ? const Color(0xFF303236) : Colors.white70;
    final muted = embedded ? const Color(0xFF8D9295) : Colors.white38;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: foreground, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeBody(
    BuildContext context,
    FileTransferModel model,
    AuthModel? authModel,
  ) {
    if (_showMaterialGallery) {
      return _buildMaterialGallery(model);
    }

    final showChat =
        _homeChatMessages.isNotEmpty ||
        _isAiGenerating ||
        _shouldShowGlobalSendProcess(model);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: showChat ? _buildChatTimeline(model) : _buildIntroPanel(authModel),
    );
  }

  Widget _buildIntroPanel(AuthModel? authModel) {
    final rawName = authModel?.currentUser?.displayName.trim() ?? '';
    final name = rawName.isEmpty ? '千瓷' : rawName;

    return LayoutBuilder(
      key: const ValueKey('intro'),
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        final horizontalPadding = compact ? 24.0 : 30.0;
        final verticalPadding = compact ? 22.0 : 40.0;
        final promptGap = compact ? 28.0 : 42.0;

        return SingleChildScrollView(
          physics: compact
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding,
            horizontalPadding,
            24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - verticalPadding - 24)
                  .clamp(0.0, double.infinity)
                  .toDouble(),
            ),
            child: Column(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $name',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 40 : 44,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '把可分享的善法资源，带到全球',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: compact ? 19 : 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: promptGap),
                Wrap(
                  spacing: compact ? 10 : 12,
                  runSpacing: compact ? 10 : 14,
                  children: [
                    _QuickPromptPill(
                      icon: Icons.auto_awesome,
                      iconColor: const Color(0xFF67AEFF),
                      label: '大乘能做什么',
                      compact: compact,
                      onTap: () => _prefillPrompt('大乘如何帮助我做全球法布施？'),
                    ),
                    _QuickPromptPill(
                      icon: Icons.public,
                      iconColor: const Color(0xFF4DDE7A),
                      label: '开始全球法布施',
                      compact: compact,
                      onTap: () => _prefillPrompt('帮我整理一段适合全球法布施的善法文字'),
                    ),
                    _QuickPromptPill(
                      icon: Icons.search_rounded,
                      iconColor: const Color(0xFFFF9F69),
                      label: 'AI找资源',
                      compact: compact,
                      onTap: () => _prefillPrompt('帮我自动查找并下载可以分享的佛法资源'),
                    ),
                    _QuickPromptPill(
                      icon: Icons.menu_book_rounded,
                      iconColor: const Color(0xFFA979FF),
                      label: '加入功课本',
                      compact: compact,
                      onTap: () => _prefillPrompt('找一份适合放进禅室功课本的经典或仪轨'),
                    ),
                    _QuickPromptPill(
                      icon: Icons.volunteer_activism_rounded,
                      iconColor: const Color(0xFFFF7D8A),
                      label: '发愿文案',
                      compact: compact,
                      onTap: () => _prefillPrompt('帮我写一段庄重、简洁的全球法布施发愿文'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMaterialGallery(FileTransferModel model) {
    final selected = _isBuddhaAssetSelected(model);
    final unlocked = _buddhaAssetUnlocked == true;

    return SingleChildScrollView(
      key: const ValueKey('materials'),
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          const Center(
            child: Text(
              '超高能素材',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.18,
              ),
            ),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 560
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _MaterialCard(
                      imagePath: AppConfig.zenBuddhaAssetCardImagePath,
                      title: '3D佛像素材',
                      priceLabel: unlocked ? '已解锁' : '¥33 解锁',
                      locked: !unlocked,
                      selected: selected,
                      onTap: () => _selectZenBuddhaMaterial(model),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatTimeline(FileTransferModel model, {bool light = false}) {
    final hasSendingProcess = _shouldShowGlobalSendProcess(model);

    return ListView(
      key: const ValueKey('chat'),
      controller: _homeChatScrollController,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      children: [
        for (final message in _homeChatMessages) ...[
          _buildChatBubble(message, model: model, light: light),
          const SizedBox(height: 18),
        ],
        if (_isAiGenerating)
          _streamingAiText.trim().isEmpty
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: _ThinkingDots(
                    label: _aiActivityText.trim().isEmpty
                        ? '正在思考'
                        : _aiActivityText.trim(),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_aiActivityText.trim().isNotEmpty) ...[
                      _AiActivityLabel(_aiActivityText.trim()),
                      const SizedBox(height: 8),
                    ],
                    _buildChatBubble(
                      _HomeChatMessage(text: _streamingAiText, isUser: false),
                      model: model,
                      light: light,
                    ),
                  ],
                ),
        if (_isAiGenerating) const SizedBox(height: 18),
        if (hasSendingProcess) _buildGlobalSendingProcess(model),
      ],
    );
  }

  Widget _buildChatBubble(
    _HomeChatMessage message, {
    required FileTransferModel model,
    bool light = false,
  }) {
    final bubbleColor = light
        ? message.isUser
              ? const Color(0xFF1B1B1D)
              : message.isError
              ? const Color(0xFFFFE8E8)
              : Colors.white.withValues(alpha: 0.82)
        : message.isUser
        ? const Color(0xFF1B1B1D)
        : message.isError
        ? Colors.red.withValues(alpha: 0.20)
        : Colors.white.withValues(alpha: 0.08);
    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(24),
      topRight: const Radius.circular(24),
      bottomLeft: Radius.circular(message.isUser ? 24 : 8),
      bottomRight: Radius.circular(message.isUser ? 8 : 24),
    );

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: light ? 680 : 430),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: radius,
          border: light && !message.isUser
              ? Border.all(
                  color: message.isError
                      ? const Color(0xFFFFC9C9)
                      : const Color(0xFFE9ECEC),
                )
              : null,
          boxShadow: light && !message.isUser
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChatBubbleBody(message, light: light),
            _buildMessageFileLinks(message, light: light),
            _buildMessageActionBar(message, model: model, light: light),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubbleBody(_HomeChatMessage message, {bool light = false}) {
    switch (message.messageType) {
      case _HomeChatMessageType.contentPreview:
        final content = message.content;
        if (content == null) {
          return _MarkdownChatText(message.text, light: light);
        }
        return _buildContentPreviewMessage(content);
      case _HomeChatMessageType.choice:
        return _buildInlineChoiceMessage(message);
      case _HomeChatMessageType.flashcardPreview:
        final deck = message.deck;
        if (deck == null) return _MarkdownChatText(message.text, light: light);
        return _buildFlashcardDeckPreview(deck);
      case _HomeChatMessageType.text:
        if (message.isUser || message.isError) {
          return Text(
            message.text,
            style: TextStyle(
              color: message.isError
                  ? light
                        ? const Color(0xFF9D1C1C)
                        : Colors.red[100]
                  : Colors.white,
              fontSize: 17,
              height: 1.42,
              fontWeight: message.isUser ? FontWeight.w700 : FontWeight.w500,
            ),
          );
        }
        return _MarkdownChatText(message.text, light: light);
    }
  }

  Widget _buildMessageActionBar(
    _HomeChatMessage message, {
    required FileTransferModel model,
    bool light = false,
  }) {
    final text = _messageActionText(message).trim();
    if (text.isEmpty) return const SizedBox.shrink();
    final canGlobalDharma =
        !message.isUser &&
        !message.isError &&
        message.messageType != _HomeChatMessageType.choice;
    final canResend = message.isUser && !message.isError;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _MessageActionButton(
            icon: Icons.copy_rounded,
            label: '复制',
            light: light,
            onTap: () => _copyMessageText(text),
          ),
          _MessageActionButton(
            icon: Icons.edit_outlined,
            label: '修改',
            light: light,
            onTap: () => _editMessageText(text),
          ),
          if (canResend)
            _MessageActionButton(
              icon: Icons.refresh_rounded,
              label: '重发',
              light: light,
              onTap: () => _resendMessageText(text, model),
            ),
          if (canGlobalDharma)
            _MessageActionButton(
              icon: Icons.public,
              label: '全球法布施',
              light: light,
              accent: true,
              onTap: () => unawaited(_sendMessageTextGlobally(text, model)),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageFileLinks(
    _HomeChatMessage message, {
    bool light = false,
  }) {
    final refs = _extractMessageFileRefs(_messageActionText(message));
    if (refs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: refs
            .take(6)
            .map(
              (ref) => _MessageFileChip(
                ref: ref,
                light: light,
                onOpen: () => unawaited(_openMessageFileRef(ref)),
                onCopy: () => _copyMessageText(ref.target),
              ),
            )
            .toList(),
      ),
    );
  }

  String _messageActionText(_HomeChatMessage message) {
    if (message.content != null) {
      final contentText = message.content!.text.trim();
      if (contentText.isNotEmpty) return contentText;
    }
    return message.text;
  }

  void _copyMessageText(String text) {
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    _showHomeSnack('已复制', ok: true);
  }

  void _editMessageText(String text) {
    _chatInputController.text = text;
    _chatInputController.selection = TextSelection.collapsed(
      offset: _chatInputController.text.length,
    );
    setState(() {
      _isDharmaComposerMode = false;
      _isFlashcardComposerMode = false;
      _showMaterialGallery = false;
    });
  }

  void _resendMessageText(String text, FileTransferModel model) {
    _editMessageText(text);
    _submitComposer(model);
  }

  Future<void> _sendMessageTextGlobally(
    String text,
    FileTransferModel model,
  ) async {
    if (text.trim().isEmpty) return;
    try {
      await model.addTextContentForSending(
        title: 'AI 回复',
        text: text.trim(),
        sourceKind: 'AI 回复',
        replaceExisting: true,
      );
      if (!mounted) return;
      _activateDharmaMode(model, target: DharmaComposerTarget.global);
      _startSending(model);
    } catch (e) {
      if (!mounted) return;
      _showHomeSnack('准备全球法布施失败：$e', ok: false);
    }
  }

  List<_MessageFileRef> _extractMessageFileRefs(String text) {
    final refs = <_MessageFileRef>[];
    final seen = <String>{};

    void addRef(String target, {String? label}) {
      final normalized = target.trim().replaceAll(RegExp(r'[),.，。；;]+$'), '');
      if (normalized.isEmpty || seen.contains(normalized)) return;
      final uri = Uri.tryParse(normalized);
      final isRemote =
          uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
      final isLocal =
          normalized.startsWith('/') || normalized.startsWith('file://');
      if (!isRemote && !isLocal) return;
      seen.add(normalized);
      refs.add(
        _MessageFileRef(
          label: (label == null || label.trim().isEmpty)
              ? _fileLabelFromTarget(normalized)
              : label.trim(),
          target: normalized,
          isRemote: isRemote,
        ),
      );
    }

    final markdownLink = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    for (final match in markdownLink.allMatches(text)) {
      addRef(match.group(2) ?? '', label: match.group(1));
    }

    final urlPattern = RegExp(r'https?://[^\s<>"\]]+');
    for (final match in urlPattern.allMatches(text)) {
      addRef(match.group(0) ?? '');
    }

    final pathPattern = RegExp(
      r'(?:file://)?/(?:[^\s<>"|]+/)*[^\s<>"|]+\.[A-Za-z0-9]{1,8}',
    );
    for (final match in pathPattern.allMatches(text)) {
      addRef(match.group(0) ?? '');
    }

    return refs;
  }

  String _fileLabelFromTarget(String target) {
    final clean = target.split('?').first.replaceFirst(RegExp(r'/$'), '');
    final lastSlash = clean.lastIndexOf('/');
    final name = lastSlash >= 0 ? clean.substring(lastSlash + 1) : clean;
    return name.isEmpty ? target : Uri.decodeComponent(name);
  }

  Future<void> _openMessageFileRef(_MessageFileRef ref) async {
    final target = ref.target;
    final uri = target.startsWith('/')
        ? Uri.file(target)
        : Uri.tryParse(target);
    if (uri == null) {
      _copyMessageText(target);
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _copyMessageText(target);
      _showHomeSnack('无法打开，已复制地址', ok: false);
    }
  }

  Widget _buildContentPreviewMessage(PreparedContent content) {
    final isDocument = content.document != null;
    final isFailed = content.isFailed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              isFailed
                  ? Icons.error_outline
                  : isDocument
                  ? Icons.description_outlined
                  : Icons.article_outlined,
              color: isFailed ? Colors.red[100] : AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isDocument ? '内容已整理为文档' : '内容预览卡',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          content.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _MiniInfoPill(content.displaySource),
            _MiniInfoPill('${content.text.runes.length} 字'),
            if (isDocument) const _MiniInfoPill('长文档'),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          isFailed
              ? (content.errorMessage ?? content.previewText)
              : content.previewText,
          maxLines: isDocument ? 4 : 7,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isFailed ? Colors.red[100] : Colors.white70,
            fontSize: 15,
            height: 1.48,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (!isFailed && content.text.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showPreparedContentDocument(content),
            icon: const Icon(Icons.open_in_full, size: 16),
            label: Text(isDocument ? '打开完整文档' : '展开全文'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInlineChoiceMessage(_HomeChatMessage message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            height: 1.35,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        for (final option in message.choices) ...[
          _InlineChoiceButton(
            icon: option.icon,
            title: option.title,
            subtitle: option.subtitle,
            selected: message.selectedValue == option.value,
            disabled:
                message.selectedValue != null &&
                message.selectedValue != option.value,
            onTap: message.selectedValue == null
                ? () => unawaited(_selectInlineChoice(message, option))
                : null,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildFlashcardDeckPreview(FlashcardDeck deck) {
    final sampleCards = deck.cards.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(
              Icons.style_outlined,
              color: AppTheme.primaryColor,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '已生成 ${deck.cardCount} 张背诵闪卡',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          deck.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _MiniInfoPill(deck.mode.label),
            _MiniInfoPill(deck.status.storageValue),
          ],
        ),
        const SizedBox(height: 12),
        for (final card in sampleCards)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              card.front,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: () => _openFlashcardDeck(deck),
          icon: const Icon(Icons.play_arrow),
          label: const Text('开始背诵'),
        ),
      ],
    );
  }

  Future<void> _selectInlineChoice(
    _HomeChatMessage message,
    _HomeChoiceOption option,
  ) async {
    if (message.selectedValue != null) return;
    HapticFeedback.lightImpact();
    setState(() => message.selectedValue = option.value);
    try {
      final callback = option.onSelected;
      if (callback != null) await Future<void>.sync(callback);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _homeChatMessages.add(
          _HomeChatMessage(text: '处理选择失败：$e', isUser: false, isError: true),
        );
      });
    }
    _scrollHomeChatToBottom(force: true);
  }

  Future<void> _showPreparedContentDocument(PreparedContent content) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (context, controller) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF202020),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Text(
                    content.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${content.text.runes.length} 字 · ${content.displaySource}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: controller,
                      child: Text(
                        content.text,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.65,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openFlashcardDeck(FlashcardDeck deck) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FlashcardStudyScreen(deck: deck, repository: _flashcardRepository),
      ),
    );
  }

  void _activateFlashcardMode({
    FlashcardCreationMode? mode,
    PreparedContent? content,
  }) {
    setState(() {
      _isFlashcardComposerMode = true;
      _isDharmaComposerMode = false;
      _showMaterialGallery = false;
      _flashcardMode = mode ?? _flashcardMode;
      _activeFlashcardContent = content ?? _activeFlashcardContent;
    });
  }

  void _clearFlashcardMode() {
    _stopFlashcardGeneration(silent: true);
    setState(() {
      _isFlashcardComposerMode = false;
      _activeFlashcardContent = null;
      _flashcardMode = FlashcardCreationMode.randomCloze;
    });
  }

  void _appendFlashcardModeChoiceMessage() {
    setState(() {
      _homeChatMessages.add(
        _HomeChatMessage.choice(
          text: '请选择背诵闪卡制作模式',
          choices: [
            _HomeChoiceOption(
              value: FlashcardCreationMode.randomCloze.storageValue,
              icon: Icons.auto_fix_high,
              title: '随机挖空',
              subtitle: '本地快速生成，无需 AI，适合立即背诵。',
              onSelected: () {
                _activateFlashcardMode(mode: FlashcardCreationMode.randomCloze);
              },
            ),
            _HomeChoiceOption(
              value: FlashcardCreationMode.aiCards.storageValue,
              icon: Icons.auto_awesome,
              title: 'AI 制卡',
              subtitle: '按你的要求生成问答/挖空卡，失败自动回退。',
              onSelected: () {
                _activateFlashcardMode(mode: FlashcardCreationMode.aiCards);
              },
            ),
          ],
        ),
      );
    });
    _scrollHomeChatToBottom(force: true);
  }

  Future<PreparedContent?> _prepareFlashcardContent(
    String composerText,
    FileTransferModel model,
  ) async {
    final text = composerText.trim();
    if (_activeFlashcardContent != null) {
      return _activeFlashcardContent;
    }

    if (text.isEmpty && model.hasSelectedContentPreview) {
      final preview = model.selectedContentPreviewText?.trim() ?? '';
      if (preview.isNotEmpty) {
        return _contentPipeline.prepare(
          ContentInput(
            text: preview,
            title: model.selectedContentTitle,
            url: model.selectedContentSourceUrl,
            sourceApp: '法布施内容',
            sourceType: 'existing_dharma_content',
          ),
        );
      }
    }

    if (text.isEmpty) {
      throw StateError('请输入链接或至少 20 个字的正文。');
    }

    final url = ContentPipeline.firstHttpUrl(text);
    return _contentPipeline.prepare(
      ContentInput(
        text: text,
        url: url,
        title: url != null ? '链接内容' : '背诵内容',
        sourceType: url != null ? 'composer_url' : 'composer_text',
      ),
    );
  }

  Future<void> _startFlashcardGeneration(FileTransferModel model) async {
    if (_isPreparingFlashcardContent || _isFlashcardGenerating) return;

    final composerText = _chatInputController.text.trim();
    final requirement = _activeFlashcardContent == null ? '' : composerText;
    final requestSerial = ++_flashcardRequestSerial;

    setState(() => _isPreparingFlashcardContent = true);
    PreparedContent content;
    try {
      content =
          await _prepareFlashcardContent(composerText, model) ??
          (throw StateError('没有可制卡的内容'));
      if (content.isFailed) {
        throw StateError(content.errorMessage ?? '内容提取失败');
      }
    } catch (e) {
      if (!mounted || requestSerial != _flashcardRequestSerial) return;
      setState(() {
        _isPreparingFlashcardContent = false;
        _homeChatMessages.add(
          _HomeChatMessage.contentPreview(
            content: PreparedContent(
              source: ContentSource(
                id: flashcardId('source_failed'),
                sourceType: 'composer_text',
                rawText: composerText,
                title: '内容准备失败',
                sourceApp: '',
                mimeType: '',
                receivedAt: DateTime.now(),
                rawTextHash: '',
              ),
              title: '内容准备失败',
              text: composerText,
              summary: '内容准备失败',
              previewText: e.toString(),
              isLong: false,
              isFailed: true,
              errorMessage: e.toString(),
            ),
          ),
        );
      });
      _scrollHomeChatToBottom(force: true);
      return;
    }

    if (!mounted || requestSerial != _flashcardRequestSerial) return;
    final inputTextForMessage = _activeFlashcardContent == null
        ? composerText
        : requirement;
    _chatInputController.clear();
    final generationMessage = _HomeChatMessage(
      text: '正在准备内容...',
      isUser: false,
    );

    setState(() {
      if (inputTextForMessage.isNotEmpty) {
        _homeChatMessages.add(
          _HomeChatMessage(text: inputTextForMessage, isUser: true),
        );
      }
      _activeFlashcardContent = content;
      _homeChatMessages.add(_HomeChatMessage.contentPreview(content: content));
      _homeChatMessages.add(generationMessage);
      _flashcardGenerationMessageId = generationMessage.id;
      _isPreparingFlashcardContent = false;
      _isFlashcardGenerating = true;
    });
    _scrollHomeChatToBottom(force: true);

    final authModel = Provider.of<AuthModel?>(context, listen: false);
    final input = FlashcardInput(
      title: content.title,
      text: content.text,
      documentId: content.document?.id,
      sourceUrl: content.sourceUrl,
      requirement: requirement,
    );
    final startedAt = DateTime.now();
    final eventStream = _flashcardMode == FlashcardCreationMode.aiCards
        ? _flashcardService.generateAiCardsStream(
            input,
            conversationId: _activeConversationId,
            token: authModel?.authToken,
            username: authModel?.currentUser?.username,
            isMember: authModel?.hasPermission('premium') ?? false,
          )
        : _flashcardService.generateRandomClozeStream(input);

    await _flashcardGenerationSubscription?.cancel();
    _flashcardGenerationSubscription = eventStream.listen(
      (event) {
        if (!mounted || requestSerial != _flashcardRequestSerial) return;
        if (event.type == FlashcardGenerationEventType.done &&
            event.deck != null) {
          final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
          setState(() {
            _replaceFlashcardGenerationMessage(
              '制卡完成：${event.deck!.cardCount} 张 · ${elapsed}ms。',
            );
            _homeChatMessages.add(
              _HomeChatMessage.flashcardPreview(deck: event.deck!),
            );
            _isFlashcardGenerating = false;
            _flashcardGenerationSubscription = null;
            _flashcardGenerationMessageId = null;
          });
          _scrollHomeChatToBottom(force: true);
          return;
        }
        if (event.type == FlashcardGenerationEventType.error) {
          setState(() {
            _replaceFlashcardGenerationMessage('制卡失败：${event.message}');
            _isFlashcardGenerating = false;
            _flashcardGenerationSubscription = null;
            _flashcardGenerationMessageId = null;
          });
          _scrollHomeChatToBottom(force: true);
          return;
        }
        final progress = event.progress > 0 ? ' (${event.progress}%)' : '';
        final cardText = event.card == null ? '' : '\n- ${event.card!.front}';
        setState(() {
          _replaceFlashcardGenerationMessage(
            '${event.message}$progress$cardText',
          );
        });
        _scrollHomeChatToBottom();
      },
      onError: (Object error) {
        if (!mounted || requestSerial != _flashcardRequestSerial) return;
        setState(() {
          _replaceFlashcardGenerationMessage('制卡失败：$error');
          _isFlashcardGenerating = false;
          _flashcardGenerationSubscription = null;
          _flashcardGenerationMessageId = null;
        });
      },
      onDone: () {
        if (!mounted || requestSerial != _flashcardRequestSerial) return;
        if (_isFlashcardGenerating) {
          setState(() => _isFlashcardGenerating = false);
        }
      },
    );
  }

  void _replaceFlashcardGenerationMessage(String text) {
    final id = _flashcardGenerationMessageId;
    if (id == null) return;
    final index = _homeChatMessages.indexWhere((message) => message.id == id);
    if (index < 0) return;
    _homeChatMessages[index].text = text;
  }

  void _stopFlashcardGeneration({bool silent = false}) {
    _flashcardRequestSerial++;
    _flashcardGenerationSubscription?.cancel();
    _flashcardGenerationSubscription = null;
    if (!mounted) return;
    setState(() {
      if (!silent) {
        _replaceFlashcardGenerationMessage('制卡已停止。可切换模式或补充正文后重新发送。');
      }
      _isPreparingFlashcardContent = false;
      _isFlashcardGenerating = false;
      _flashcardGenerationMessageId = null;
    });
  }

  void _appendIncomingShareChoiceMessage(
    IncomingSharePayload payload,
    PreparedContent content,
    FileTransferModel model,
  ) {
    setState(() {
      _homeChatMessages.add(
        _HomeChatMessage.choice(
          text: '请选择处理方式\n来源：${payload.displaySource}',
          choices: [
            _HomeChoiceOption(
              value: 'global_dharma',
              icon: Icons.public,
              title: '全球法布施',
              subtitle: '把整理后的内容发送到全球节点。',
              onSelected: () async {
                await _usePreparedContentForDharma(model, content);
                _activateDharmaMode(model, target: DharmaComposerTarget.global);
              },
            ),
            _HomeChoiceOption(
              value: 'platform_publish',
              icon: Icons.campaign_outlined,
              title: '法布施到平台',
              subtitle: '生成平台发布草稿并预览。',
              onSelected: () async {
                await _usePreparedContentForDharma(model, content);
                _activateDharmaMode(
                  model,
                  target: DharmaComposerTarget.platform,
                );
                await _showPublishPlatformSelector();
              },
            ),
            _HomeChoiceOption(
              value: 'flashcards',
              icon: Icons.style_outlined,
              title: '制作背诵闪卡',
              subtitle: '随机挖空或 AI 制卡，进入背诵页。',
              onSelected: () {
                _activateFlashcardMode(content: content);
              },
            ),
          ],
        ),
      );
    });
  }

  Future<void> _usePreparedContentForDharma(
    FileTransferModel model,
    PreparedContent content,
  ) async {
    await model.addTextContentForSending(
      title: content.title,
      text: content.text,
      sourceKind: content.sourceUrl == null ? '文本' : '链接',
      sourceUrl: content.sourceUrl,
      previewText: content.previewText,
      replaceExisting: true,
    );
    if (mounted) setState(() {});
  }

  bool _shouldShowGlobalSendProcess(FileTransferModel model) {
    return _isGlobalSendTimelineVisible || model.isPreparingSend;
  }

  Widget _buildGlobalSendingProcess(FileTransferModel model) {
    final label = model.isPreparingSend
        ? (model.preparingSendMessage.isEmpty
              ? '正在准备全球发送'
              : model.preparingSendMessage)
        : model.isTransferring
        ? _currentSendingCountry.isEmpty
              ? '正在全球发送'
              : '正在发送到 $_currentSendingCountry'
        : '正在整理本次发送数据';

    final successCount = model.countryStatuses
        .where((status) => status.status == SendStatus.success)
        .length;
    final totalCount = model.countryStatuses.length;

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ThinkingDots(label: label),
          const SizedBox(height: 14),
          _buildScenePreview(),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxWidth: 430),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    totalCount == 0
                        ? '已传播 ${model.globalSentCount} 个节点'
                        : '已完成 $successCount / $totalCount 个国家',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${model.globalDataSentMB.toStringAsFixed(2)} MB',
                  style: TextStyle(
                    color: AppTheme.primaryColor.withValues(alpha: 0.95),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenePreview() {
    final useThreeD = _isThreeDActiveNow;

    return GestureDetector(
      onTap: _openFullScreenScene,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        height: 268,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.46),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isGlobeLoaded)
              useThreeD
                  ? EarthGlobeWidget(key: _globe3DKey)
                  : HomeWorld2DWidget(key: _world2DKey)
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.cyan),
              ),
            Positioned(
              top: 12,
              left: 12,
              child: InkWell(
                onTap: _toggleSceneRenderMode,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    useThreeD ? '3D' : '2D',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.48),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.fullscreen_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _prefillPrompt(String prompt) {
    _chatInputController.text = prompt;
    _chatInputController.selection = TextSelection.collapsed(
      offset: _chatInputController.text.length,
    );
    setState(() {
      _showMaterialGallery = false;
      _isDharmaComposerMode = false;
      _isFlashcardComposerMode = false;
    });
  }

  String _conversationTitleFrom(List<_HomeChatMessage> messages) {
    String? firstUserMessage;
    for (final message in messages) {
      final text = message.text.trim();
      if (message.isUser && text.isNotEmpty) {
        firstUserMessage = text;
        break;
      }
    }
    final raw = firstUserMessage ?? '你好';
    return raw.length > 18 ? '${raw.substring(0, 18)}...' : raw;
  }

  void _snapshotCurrentConversation({bool isGlobalSendRunning = false}) {
    if (_homeChatMessages.isEmpty) return;
    final snapshot = _HomeConversation(
      id: _activeConversationId,
      title: _conversationTitleFrom(_homeChatMessages),
      messages: List<_HomeChatMessage>.from(_homeChatMessages),
      updatedAt: DateTime.now(),
      isGlobalSendRunning: isGlobalSendRunning,
    );
    _conversationHistory.removeWhere(
      (item) =>
          (snapshot.id != null && item.id == snapshot.id) ||
          item.title == snapshot.title,
    );
    _conversationHistory.insert(0, snapshot);
    if (_conversationHistory.length > 30) {
      _conversationHistory.removeRange(30, _conversationHistory.length);
    }
  }

  void _startNewConversation(FileTransferModel model) {
    final hasRunningGlobalSend =
        model.isPreparingSend ||
        model.isTransferring ||
        _isGlobalSendTimelineVisible;
    _snapshotCurrentConversation(isGlobalSendRunning: hasRunningGlobalSend);
    _stopAiGeneration();
    if (!hasRunningGlobalSend) {
      model.clearFiles();
    }
    _chatInputController.clear();
    setState(() {
      _activeConversationId = null;
      _homeChatMessages.clear();
      _streamingAiText = '';
      _aiActivityText = '';
      _isDharmaComposerMode = false;
      _showMaterialGallery = false;
      _isGlobalSendTimelineVisible = false;
      if (!hasRunningGlobalSend) {
        _currentSendingCountry = '';
        _activeSendTitle = '';
        _activeSendRegion = '';
        _sendStartedAt = null;
      }
    });
    Navigator.maybePop(context);
  }

  Future<void> _openConversation(_HomeConversation conversation) async {
    final model = Provider.of<FileTransferModel>(context, listen: false);
    _snapshotCurrentConversation(
      isGlobalSendRunning:
          model.isPreparingSend ||
          model.isTransferring ||
          _isGlobalSendTimelineVisible,
    );
    _stopAiGeneration();
    _chatInputController.clear();
    var messages = conversation.messages;
    final conversationId = conversation.id;

    if (conversationId != null && conversationId.isNotEmpty) {
      try {
        final authModel = Provider.of<AuthModel?>(context, listen: false);
        final remoteMessages = await _dachengAiService.getConversationMessages(
          conversationId: conversationId,
          token: authModel?.authToken,
          isMember: authModel?.hasPermission('premium') ?? false,
        );
        messages = remoteMessages
            .map(
              (message) => _HomeChatMessage(
                text: message.content,
                isUser: message.role == 'user',
              ),
            )
            .toList();
      } catch (e) {
        debugPrint('打开大乘 AI 历史失败: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _activeConversationId = conversationId;
      _homeChatMessages
        ..clear()
        ..addAll(messages);
      _streamingAiText = '';
      _aiActivityText = '';
      _isDharmaComposerMode = false;
      _showMaterialGallery = false;
      _isGlobalSendTimelineVisible = conversation.isGlobalSendRunning;
      if (!conversation.isGlobalSendRunning) {
        _currentSendingCountry = '';
        _activeSendTitle = '';
        _activeSendRegion = '';
        _sendStartedAt = null;
      }
    });
    Navigator.maybePop(context);
    _scrollHomeChatToBottom();
  }

  Future<void> _selectZenBuddhaMaterial(FileTransferModel model) async {
    _activateDharmaMode(model, showMaterials: true);
    final unlocked = await _ensureBuddhaAssetUnlocked();
    if (!unlocked) return;

    try {
      await model.addZenBuddhaAssetForSending();
      if (!mounted) return;
      setState(() {
        _buddhaAssetUnlocked = true;
        _isDharmaComposerMode = true;
        _showMaterialGallery = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('素材准备失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openFullScreenScene() async {
    final model = Provider.of<FileTransferModel>(context, listen: false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenSendScene(
          useThreeD: _isThreeDActiveNow,
          model: model,
          onClose: () {
            _isCallbackSetup = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _setupTransferBeamCallback();
            });
          },
        ),
      ),
    );
  }

  Widget _buildChatComposer(BuildContext context, FileTransferModel model) {
    final isBusy =
        model.isPreparingSend ||
        _isPublishingDraft ||
        _isPreparingFlashcardContent ||
        _isFlashcardGenerating ||
        (_isDharmaComposerMode && model.isTransferring);
    final inputText = _chatInputController.text.trim();
    final hasFlashcardContext =
        (_activeFlashcardContent?.text.trim().isNotEmpty ?? false);
    final canSubmit = _isFlashcardComposerMode
        ? !_isPreparingFlashcardContent &&
              !_isFlashcardGenerating &&
              (inputText.isNotEmpty || hasFlashcardContext)
        : _isDharmaComposerMode
        ? _dharmaComposerTarget == DharmaComposerTarget.platform
              ? (inputText.isNotEmpty || model.hasFiles) &&
                    _selectedPublishPlatforms.isNotEmpty
              : (inputText.isNotEmpty || model.hasFiles)
        : inputText.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 7, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF242424).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(
          (_isDharmaComposerMode || _isFlashcardComposerMode) ? 24 : 26,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isFlashcardComposerMode) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 1, 6, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _ComposerChip(
                    icon: Icons.style_outlined,
                    label: '背诵闪卡',
                    active: true,
                    onRemove: _isFlashcardGenerating
                        ? null
                        : _clearFlashcardMode,
                  ),
                  _ComposerChip(
                    icon: _flashcardMode == FlashcardCreationMode.aiCards
                        ? Icons.auto_awesome
                        : Icons.auto_fix_high,
                    label: '模式 ${_flashcardMode.label}',
                    active: true,
                    onTap: isBusy ? null : _appendFlashcardModeChoiceMessage,
                  ),
                  if (_activeFlashcardContent != null)
                    _ComposerChip(
                      icon: _activeFlashcardContent!.hasDocument
                          ? Icons.description_outlined
                          : Icons.article_outlined,
                      label: _activeFlashcardContent!.hasDocument
                          ? '文档 ${_activeFlashcardContent!.title}'
                          : '内容 ${_activeFlashcardContent!.title}',
                      active: true,
                      onTap: () => _showPreparedContentDocument(
                        _activeFlashcardContent!,
                      ),
                      onRemove: isBusy
                          ? null
                          : () =>
                                setState(() => _activeFlashcardContent = null),
                    ),
                ],
              ),
            ),
          ] else if (_isDharmaComposerMode) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 1, 6, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _ComposerChip(
                    icon: Icons.self_improvement,
                    label: '法布施',
                    active: true,
                    onRemove: () => _clearDharmaMode(model),
                  ),
                  if (_dharmaComposerTarget == DharmaComposerTarget.platform)
                    _ComposerChip(
                      icon: Icons.campaign_outlined,
                      label: '平台 ${_platformSummary()}',
                      active: _selectedPublishPlatforms.isNotEmpty,
                      onTap: isBusy
                          ? null
                          : () => _showPublishPlatformSelector(),
                    )
                  else ...[
                    _ComposerChip(
                      icon: Icons.public,
                      label: '地区 ${_regionSummary(model)}',
                      active:
                          model.isGlobalSendEnabled ||
                          model.isFieldEnergyMode ||
                          model.isLocalLoopbackEnabled,
                      onTap: isBusy ? null : () => _showRegionSelector(model),
                    ),
                    _ComposerChip(
                      icon: Icons.loop,
                      label: model.isLooping ? '循环' : '单轮',
                      active: model.isLooping,
                      onTap: isBusy
                          ? null
                          : () {
                              model.setLooping(!model.isLooping);
                              setState(() {});
                            },
                    ),
                  ],
                  if (model.hasFiles)
                    _ComposerChip(
                      icon: _contentIcon(model.selectedContentKind),
                      label: model.selectedContentTitle.isEmpty
                          ? '图片'
                          : model.selectedContentTitle,
                      active: true,
                      onTap: model.hasSelectedContentPreview
                          ? () => _showSelectedContentPreview(model)
                          : null,
                      onRemove: isBusy
                          ? null
                          : () {
                              model.clearFiles();
                              setState(() {});
                            },
                    ),
                ],
              ),
            ),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Builder(
                builder: (buttonContext) => IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '更多入口',
                  icon: const Icon(Icons.add, color: Colors.white, size: 24),
                  onPressed: isBusy
                      ? null
                      : () => _openSendContentMenu(buttonContext, model),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    disabledBackgroundColor: Colors.white.withValues(
                      alpha: 0.04,
                    ),
                    fixedSize: const Size(40, 40),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _chatInputController,
                  enabled:
                      !model.isPreparingSend &&
                      !_isPreparingFlashcardContent &&
                      !_isFlashcardGenerating &&
                      (!model.isTransferring || !_isDharmaComposerMode),
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.35,
                  ),
                  cursorColor: AppTheme.primaryColor,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: _isDharmaComposerMode
                        ? _dharmaComposerTarget == DharmaComposerTarget.platform
                              ? (model.hasFiles ? '可继续输入发布说明' : '粘贴要发布的链接或正文')
                              : (model.hasFiles ? '可继续输入法布施文字或链接' : '输入文字或链接')
                        : _isFlashcardComposerMode
                        ? _flashcardMode == FlashcardCreationMode.aiCards
                              ? (_activeFlashcardContent == null
                                    ? '粘贴链接或正文，发送后 AI 制卡'
                                    : '输入制卡要求，例如：按重点概念出题')
                              : '输入链接或正文，发送后自动挖空'
                        : '问问大乘',
                    hintStyle: const TextStyle(
                      color: Colors.white54,
                      fontSize: 15,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (canSubmit) _submitComposer(model);
                  },
                ),
              ),
              const SizedBox(width: 6),
              _buildComposerActionButton(model, canSubmit: canSubmit),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopChatComposer(
    BuildContext context,
    FileTransferModel model,
  ) {
    final isBusy =
        model.isPreparingSend ||
        _isPublishingDraft ||
        _isPreparingFlashcardContent ||
        _isFlashcardGenerating ||
        (_isDharmaComposerMode && model.isTransferring);
    final inputText = _chatInputController.text.trim();
    final hasFlashcardContext =
        (_activeFlashcardContent?.text.trim().isNotEmpty ?? false);
    final canSubmit = _isFlashcardComposerMode
        ? !_isPreparingFlashcardContent &&
              !_isFlashcardGenerating &&
              (inputText.isNotEmpty || hasFlashcardContext)
        : _isDharmaComposerMode
        ? _dharmaComposerTarget == DharmaComposerTarget.platform
              ? (inputText.isNotEmpty || model.hasFiles) &&
                    _selectedPublishPlatforms.isNotEmpty
              : (inputText.isNotEmpty || model.hasFiles)
        : inputText.isNotEmpty;

    return CodexDesktopChatInput(
      controller: _chatInputController,
      isBusy: isBusy,
      canSubmit: canSubmit,
      onTextChanged: () => setState(() {}),
      onAddActionSelected: (action) => _handleSendMenuAction(model, action),
      modelOptions: _desktopModelOptions,
      selectedModelId: _selectedDesktopModelId,
      onModelChanged: (modelId) {
        setState(() => _selectedDesktopModelId = modelId);
      },
      selectedProject: _selectedDesktopProject,
      onProjectChanged: (project) {
        setState(() => _selectedDesktopProject = project);
      },
      onSubmit: () {
        _submitComposer(model);
      },
    );
  }

  // ignore: unused_element
  Widget _buildDesktopModeMenu() {
    return PopupMenuButton<String>(
      tooltip: '模型模式',
      onSelected: (value) => setState(() => _openClawModeLabel = value),
      itemBuilder: (context) => const [
        PopupMenuItem(value: '自动', child: Text('自动')),
        PopupMenuItem(value: '本机全能', child: Text('本机全能')),
        PopupMenuItem(value: '远程接管', child: Text('远程接管')),
        PopupMenuItem(value: '微信待命', child: Text('微信待命')),
      ],
      child: _DesktopComposerButton(
        icon: Icons.psychology_alt_outlined,
        label: _openClawModeLabel,
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDesktopSkillsMenu() {
    return PopupMenuButton<String>(
      tooltip: '技能',
      onSelected: _handleDesktopSkillSelection,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'find', child: Text('find-skills')),
        PopupMenuItem(value: 'publish', child: Text('media-auto-publisher')),
        PopupMenuItem(
          value: 'wechat-draft',
          child: Text('wechat-draft-publisher'),
        ),
        PopupMenuItem(value: 'browser', child: Text('Web Access')),
        PopupMenuItem(value: 'doc', child: Text('PDF / Word / Excel')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'import', child: Text('导入技能')),
      ],
      child: const _DesktopComposerButton(
        icon: Icons.handyman_outlined,
        label: '技能',
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDesktopConnectMenu() {
    return PopupMenuButton<String>(
      tooltip: '连应用',
      onSelected: _handleDesktopConnectorSelection,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'wechat', child: Text('微信')),
        PopupMenuItem(value: 'wechatPlugin', child: Text('安装微信插件')),
        PopupMenuItem(value: 'mobile', child: Text('移动端')),
        PopupMenuItem(value: 'chrome', child: Text('Chrome')),
        PopupMenuItem(value: 'desktop', child: Text('本机桌面')),
        PopupMenuItem(value: 'remote', child: Text('远程入口')),
        PopupMenuItem(value: 'permissions', child: Text('系统权限')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'restart', child: Text('重启本机 AI')),
        PopupMenuItem(value: 'channels', child: Text('渠道状态')),
        PopupMenuItem(value: 'log', child: Text('复制诊断日志')),
      ],
      child: const _DesktopComposerButton(
        icon: Icons.link_outlined,
        label: '连应用',
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDesktopPermissionMenu() {
    return PopupMenuButton<String>(
      tooltip: '权限',
      onSelected: (value) {
        setState(() => _openClawPermissionLabel = value);
        if (value == '完全访问权限') {
          unawaited(_loadOpenClawHomeStatus(probeOpenClaw: true));
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: '默认权限', child: Text('默认权限')),
        PopupMenuItem(value: '完全访问权限', child: Text('完全访问权限')),
      ],
      child: _DesktopComposerButton(
        icon: Icons.verified_user_outlined,
        label: _openClawPermissionLabel,
      ),
    );
  }

  Widget _buildComposerActionButton(
    FileTransferModel model, {
    required bool canSubmit,
  }) {
    if (_isPreparingFlashcardContent) {
      return Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_isFlashcardGenerating) {
      return IconButton(
        tooltip: '停止制卡',
        icon: const Icon(Icons.stop, color: Colors.white, size: 21),
        onPressed: _stopFlashcardGeneration,
        style: IconButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          fixedSize: const Size(42, 42),
        ),
      );
    }

    if (_isPublishingDraft) {
      return Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (model.isPreparingSend) {
      return Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_isAiGenerating) {
      return IconButton(
        tooltip: '停止生成',
        icon: const Icon(Icons.stop, color: Colors.white, size: 21),
        onPressed: _stopAiGeneration,
        style: IconButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          fixedSize: const Size(42, 42),
        ),
      );
    }

    if (model.isTransferring && _isGlobalSendTimelineVisible) {
      return IconButton(
        tooltip: '停止发送',
        icon: const Icon(Icons.stop, color: Colors.white, size: 21),
        onPressed: () => _stopSending(model),
        style: IconButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          fixedSize: const Size(42, 42),
        ),
      );
    }

    return IconButton(
      tooltip: _isFlashcardComposerMode
          ? '开始制卡'
          : _isDharmaComposerMode
          ? _dharmaComposerTarget == DharmaComposerTarget.platform
                ? '预览并发布'
                : '开始法布施'
          : '发送问题',
      icon: Icon(
        Icons.arrow_upward,
        color: canSubmit ? Colors.black : Colors.white54,
        size: 22,
      ),
      onPressed: canSubmit ? () => _submitComposer(model) : null,
      style: IconButton.styleFrom(
        backgroundColor: canSubmit
            ? Colors.white
            : Colors.white.withValues(alpha: 0.1),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
        fixedSize: const Size(42, 42),
      ),
    );
  }

  Future<bool> _openSendContentMenu(
    BuildContext anchorContext,
    FileTransferModel model,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final anchor = anchorContext.findRenderObject() as RenderBox?;
    if (overlay == null || anchor == null) return false;

    final anchorTopLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final anchorBottomRight = anchor.localToGlobal(
      anchor.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final position = RelativeRect.fromRect(
      Rect.fromPoints(anchorTopLeft, anchorBottomRight),
      Offset.zero & overlay.size,
    );

    final action = await showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF333333),
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      items: [
        _sendMenuItem(
          'dharma',
          Icons.self_improvement,
          '全球法布施',
          _isDharmaComposerMode &&
                  _dharmaComposerTarget == DharmaComposerTarget.global
              ? '已选择，可在输入框上方调整'
              : '默认全球发送',
        ),
        _sendMenuItem(
          'platform_publish',
          Icons.campaign_outlined,
          '法布施到平台',
          '公众号、小红书、抖音、微博等多选',
        ),
        _sendMenuItem(
          'flashcards',
          Icons.style_outlined,
          '背诵闪卡',
          '把链接或正文制作成可背诵卡片',
        ),
        _sendMenuItem(
          'files',
          Icons.add_photo_alternate,
          '添加图片和文件',
          '选择本机图片或文件',
        ),
      ],
    );

    if (action == null) return false;
    return _handleSendMenuAction(model, action);
  }

  PopupMenuItem<String> _sendMenuItem(
    String value,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 54,
      child: _SendMenuRow(icon: icon, title: title, subtitle: subtitle),
    );
  }

  Future<bool> _handleSendMenuAction(
    FileTransferModel model,
    String action,
  ) async {
    if (action == 'dharma') {
      _activateDharmaMode(model);
      setState(() => _showMaterialGallery = true);
      return true;
    }
    if (action == 'platform_publish') {
      _activateDharmaMode(model, target: DharmaComposerTarget.platform);
      await _showPublishPlatformSelector();
      return _selectedPublishPlatforms.isNotEmpty;
    }
    if (action == 'flashcards') {
      _activateFlashcardMode();
      _appendFlashcardModeChoiceMessage();
      return true;
    }
    if (action == 'files') {
      _activateDharmaMode(model, target: _dharmaComposerTarget);
      final selected = await model.selectFiles(replaceExisting: true);
      if (selected && mounted) setState(() {});
      return selected;
    }
    return false;
  }

  void _handleDesktopSkillSelection(String value) {
    switch (value) {
      case 'find':
        _prefillPrompt('帮我查找并安装适合当前任务的 OpenClaw 技能');
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

  void _handleDesktopConnectorSelection(String value) {
    switch (value) {
      case 'wechat':
        unawaited(_loginOpenClawHomeWeChat());
        break;
      case 'wechatPlugin':
        unawaited(_installOpenClawHomeWeChatPlugin());
        break;
      case 'mobile':
        unawaited(_createOpenClawHomeMobilePairingCode());
        break;
      case 'chrome':
        unawaited(_prepareHomeChromeConnector());
        break;
      case 'desktop':
        unawaited(_startDesktopBridgeFromHome());
        break;
      case 'remote':
        unawaited(_editOpenClawHomeRemoteGatewayUrl());
        break;
      case 'permissions':
        unawaited(
          _requestHomeDesktopPermission(
            screenRecording:
                _desktopControlStatus?.screenRecordingGranted != true,
          ),
        );
        break;
      case 'restart':
        unawaited(_restartOpenClawFromHome());
        break;
      case 'channels':
        unawaited(_inspectOpenClawHomeChannels());
        break;
      case 'log':
        unawaited(_copyDiagnosticLogTailFromHome());
        break;
    }
  }

  Map<String, dynamic> _desktopAiClientContext() {
    final project = _selectedDesktopProject;
    return {
      'surface': 'fabushi_desktop_home',
      'selectedModel': _selectedDesktopModelId,
      if (project != null)
        'project': {
          'name': project.name,
          'path': project.path,
          'isExternal': project.isExternal,
        },
    };
  }

  bool _looksLikeGlobalDharmaIntent(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return false;
    if (compact.contains('全球法布施') || compact.contains('全局法布施')) {
      return true;
    }
    if (!compact.contains('法布施')) return false;
    return compact.contains('开始') ||
        compact.contains('进行') ||
        compact.contains('发送') ||
        compact.contains('传播') ||
        compact.contains('分享') ||
        compact.contains('发出去') ||
        compact.contains('自动');
  }

  bool _isBareGlobalDharmaCommand(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    if (compact.length > 18) return false;
    if (RegExp(r'https?://').hasMatch(text)) return false;
    return RegExp(
      r'^(请|帮我|我要|开始|进行|自动|去|把|将)*全球?法布施(一下|吧|。|！|!)*$',
    ).hasMatch(compact);
  }
  void _submitComposer(FileTransferModel model) {
    if (_isFlashcardComposerMode) {
      unawaited(_startFlashcardGeneration(model));
      return;
    }

    final inputText = _chatInputController.text.trim();
    final isUrl = Uri.tryParse(inputText)?.hasAbsolutePath ?? false;

    if (!_isDharmaComposerMode && _looksLikeGlobalDharmaIntent(inputText)) {
      _activateDharmaMode(model, target: DharmaComposerTarget.global);
      if (_isBareGlobalDharmaCommand(inputText) && !model.hasFiles) {
        _chatInputController.clear();
        setState(() {
          _showMaterialGallery = true;
          _homeChatMessages.add(
            _HomeChatMessage(
              text: '已打开全球法布施。请输入要发送的文字/链接，或点 + 添加素材。',
              isUser: false,
            ),
          );
        });
        _scrollHomeChatToBottom(force: true);
        return;
      }
      _startSending(model);
      return;
    }

    if (isUrl && !_isDharmaComposerMode) {
      unawaited(_handleUrlToDharmaMaterial(inputText, model));
      return;
    }

    if (_isDharmaComposerMode) {
      if (_dharmaComposerTarget == DharmaComposerTarget.platform) {
        unawaited(_startPlatformPublish(model));
      } else {
        _startSending(model);
      }
    } else {
      unawaited(_sendAiChatFromComposer());
    }
  }

  Future<void> _handleUrlToDharmaMaterial(
    String url,
    FileTransferModel model,
  ) async {
    final authModel = Provider.of<AuthModel?>(context, listen: false);
    _chatInputController.clear();

    setState(() {
      _homeChatMessages.add(
        _HomeChatMessage(text: '提取并发布此链接: $url', isUser: true),
      );
      _isAiGenerating = true;
      _streamingAiText = '';
      _aiActivityText = '正在抓取链接内容作为法布施素材...';
    });
    _scrollHomeChatToBottom(force: true);

    try {
      var finalText = '';
      final prompt =
          '请读取此网页的内容，并为其生成一段适合用于全球法布施的正能量摘要素材，直接输出文字不要包含多余的对话和解释：$url';

      await for (final event in _dachengAiService.sendChatStream(
        message: prompt,
        conversationId: _activeConversationId,
        model: _selectedDesktopModelId,
        client: _desktopAiClientContext(),
        token: authModel?.authToken,
        username: authModel?.currentUser?.username,
        isMember: authModel?.hasPermission('premium') ?? false,
      )) {
        if (!mounted) return;

        if (event.isDelta) {
          finalText += event.text;
          setState(() {
            _streamingAiText = finalText;
            _aiActivityText = '正在生成法布施素材...';
          });
          _scrollHomeChatToBottom();
        } else if (event.isDone) {
          break;
        }
      }

      if (!mounted) return;

      setState(() {
        _homeChatMessages.add(_HomeChatMessage(text: finalText, isUser: false));
        _streamingAiText = '';
        _isAiGenerating = false;
        _aiActivityText = '';
      });

      // Transform text into Dharma material and send globally
      _chatInputController.text = finalText;
      _activateDharmaMode(model, target: DharmaComposerTarget.global);

      // Auto-start sending
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _startSending(model);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAiGenerating = false;
        _aiActivityText = '';
        _homeChatMessages.add(
          _HomeChatMessage(text: '链接读取失败: $e', isUser: false),
        );
      });
      _scrollHomeChatToBottom(force: true);
    }
  }

  void _activateDharmaMode(
    FileTransferModel model, {
    bool showMaterials = false,
    DharmaComposerTarget target = DharmaComposerTarget.global,
  }) {
    if (target == DharmaComposerTarget.global) {
      if (model.countryList.isEmpty) {
        model.setCountryList(['ALL']);
      }
      if (!model.isGlobalSendEnabled &&
          !model.isFieldEnergyMode &&
          !model.isLocalLoopbackEnabled) {
        model.setGlobalSendEnabled(true);
        model.setCountryList(['ALL']);
      }
    }
    setState(() {
      _isDharmaComposerMode = true;
      _isFlashcardComposerMode = false;
      _dharmaComposerTarget = target;
      _showMaterialGallery =
          showMaterials && target == DharmaComposerTarget.global;
    });
  }

  void _clearDharmaMode(FileTransferModel model) {
    _chatInputController.clear();
    model.clearFiles();
    setState(() {
      _isDharmaComposerMode = false;
      _isFlashcardComposerMode = false;
      _activeFlashcardContent = null;
      _dharmaComposerTarget = DharmaComposerTarget.global;
      _showMaterialGallery = false;
    });
  }

  String _regionSummary(FileTransferModel model) {
    final labels = <String>[];

    if (model.isGlobalSendEnabled && model.countryList.isNotEmpty) {
      if (model.countryList.contains('ALL')) {
        labels.add('全球');
      } else {
        final countryNames = model.countryList
            .where(country_catalog.GLOBAL_COUNTRY_SERVERS.containsKey)
            .map(_countryName)
            .toList();
        if (countryNames.length <= 2) {
          labels.add(countryNames.join('、'));
        } else if (countryNames.isNotEmpty) {
          labels.add('${countryNames.length} 个国家');
        }
      }
    }

    if (model.isFieldEnergyMode) labels.add('本地场能');
    if (model.isLocalLoopbackEnabled) labels.add('本地转经轮');

    return labels.isEmpty ? '未选择' : labels.join('、');
  }

  String _countryName(String code) {
    return country_catalog.COUNTRY_NAMES[code] ?? code;
  }

  List<MapEntry<String, String>> get _countryOptions {
    final entries = country_catalog.GLOBAL_COUNTRY_SERVERS.keys
        .map((code) => MapEntry(code, _countryName(code)))
        .toList();
    entries.sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  String _platformSummary() {
    if (_selectedPublishPlatforms.isEmpty) return '未选择';
    final labels = _selectedPublishPlatforms
        .map((platform) => platform.info.shortLabel)
        .toList();
    if (labels.length <= 2) return labels.join('、');
    return '${labels.take(2).join('、')} 等 ${labels.length} 个';
  }

  Future<void> _showPublishPlatformSelector() async {
    final selected = Set<DharmaPublishPlatform>.from(_selectedPublishPlatforms);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.76,
                ),
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                decoration: const BoxDecoration(
                  color: Color(0xFF202020),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '选择法布施平台',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setSheetState(() {
                            selected
                              ..clear()
                              ..addAll(DharmaPublishService.allPlatforms);
                          }),
                          child: const Text('全选'),
                        ),
                        TextButton(
                          onPressed: () => setSheetState(selected.clear),
                          child: const Text('清空'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '发布前会先下载/整理链接内容，缺少标题或正文时会在对话里补全并预览。',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final platform
                              in DharmaPublishService.allPlatforms)
                            _PlatformCheckTile(
                              platform: platform,
                              selected: selected.contains(platform),
                              onChanged: (checked) {
                                setSheetState(() {
                                  if (checked) {
                                    selected.add(platform);
                                  } else {
                                    selected.remove(platform);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: selected.isEmpty
                                ? null
                                : () {
                                    setState(() {
                                      _selectedPublishPlatforms
                                        ..clear()
                                        ..addAll(selected);
                                    });
                                    Navigator.pop(sheetContext);
                                  },
                            child: const Text('完成'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _consumeInitialShare() async {
    final payload = await InboundShareService.instance.takeInitialShare();
    if (payload == null || payload.isEmpty || !mounted) return;
    await _handleIncomingShare(payload);
    await InboundShareService.instance.clearInitialShare();
  }

  Future<void> _handleIncomingShare(IncomingSharePayload payload) async {
    if (!mounted || payload.isEmpty) return;
    final fingerprint =
        '${payload.bestText}|${payload.title}|${payload.sourcePackage}';
    if (_lastIncomingShareFingerprint == fingerprint) return;
    _lastIncomingShareFingerprint = fingerprint;

    final model = Provider.of<FileTransferModel>(context, listen: false);
    final sharedText = _normalizeIncomingShareText(payload);
    final candidateUrl = payload.url.trim().isNotEmpty
        ? payload.url.trim()
        : _firstHttpUrl(sharedText);
    final composerText = candidateUrl ?? sharedText;
    if (composerText.trim().isEmpty) return;

    setState(() {
      _homeChatMessages.add(
        _HomeChatMessage(
          text: [
            '已接收外部分享。',
            '来源：${payload.displaySource}',
            if (payload.title.trim().isNotEmpty) '标题：${payload.title.trim()}',
            if (candidateUrl != null) '链接：$candidateUrl',
          ].join('\n'),
          isUser: false,
        ),
      );
      _isPreparingFlashcardContent = true;
    });
    _scrollHomeChatToBottom(force: true);

    PreparedContent content;
    try {
      content = await _contentPipeline.prepare(
        ContentInput(
          text: sharedText.isEmpty ? composerText : sharedText,
          url: candidateUrl,
          title: payload.title.trim().isEmpty ? '外部分享' : payload.title.trim(),
          sourceApp: payload.displaySource,
          mimeType: payload.mimeType,
          sourceType: 'external_share',
        ),
      );
    } catch (e) {
      content = PreparedContent(
        source: ContentSource(
          id: flashcardId('share_failed'),
          sourceType: 'external_share',
          rawText: composerText,
          url: candidateUrl,
          title: payload.title.trim().isEmpty ? '外部分享' : payload.title.trim(),
          sourceApp: payload.displaySource,
          mimeType: payload.mimeType,
          receivedAt: payload.receivedAt,
          rawTextHash: '',
        ),
        title: payload.title.trim().isEmpty ? '外部分享' : payload.title.trim(),
        text: composerText,
        summary: '外部分享内容提取失败',
        previewText: e.toString(),
        isLong: false,
        isFailed: true,
        errorMessage: e.toString(),
      );
    }

    if (!mounted) return;
    setState(() {
      _isPreparingFlashcardContent = false;
      _activeFlashcardContent = content.isFailed ? null : content;
      _chatInputController.clear();
      _homeChatMessages.add(_HomeChatMessage.contentPreview(content: content));
    });
    if (content.isFailed) {
      _chatInputController.text = composerText.trim();
      _chatInputController.selection = TextSelection.collapsed(
        offset: _chatInputController.text.length,
      );
      setState(() {
        _homeChatMessages.add(
          _HomeChatMessage(
            text: '链接或分享内容暂时无法自动提取。你可以在输入框里改为粘贴正文后，再选择法布施或背诵闪卡。',
            isUser: false,
            isError: true,
          ),
        );
      });
    } else {
      _appendIncomingShareChoiceMessage(payload, content, model);
    }
    _scrollHomeChatToBottom(force: true);
  }

  // ignore: unused_element
  Future<DharmaComposerTarget?> _showIncomingShareTargetSheet(
    IncomingSharePayload payload,
    String text,
  ) {
    final preview = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return showModalBottomSheet<DharmaComposerTarget>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            decoration: const BoxDecoration(
              color: Color(0xFF202020),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const Text(
                  '收到外部分享',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  preview.length > 120
                      ? '${preview.substring(0, 120)}...'
                      : preview,
                  style: const TextStyle(color: Colors.white60, height: 1.35),
                ),
                const SizedBox(height: 16),
                _ShareTargetTile(
                  icon: Icons.public,
                  title: '全球法布施',
                  subtitle: '把链接放入输入框，点击发送后下载内容并进行全球法布施。',
                  onTap: () =>
                      Navigator.pop(sheetContext, DharmaComposerTarget.global),
                ),
                const SizedBox(height: 10),
                _ShareTargetTile(
                  icon: Icons.campaign_outlined,
                  title: '法布施到平台',
                  subtitle: '选择公众号、小红书、抖音、微博等平台，补齐标题正文后预览发布。',
                  onTap: () => Navigator.pop(
                    sheetContext,
                    DharmaComposerTarget.platform,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('先放到输入框'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _normalizeIncomingShareText(IncomingSharePayload payload) {
    final parts = <String>[
      if (payload.title.trim().isNotEmpty) payload.title.trim(),
      if (payload.text.trim().isNotEmpty) payload.text.trim(),
      if (payload.url.trim().isNotEmpty && !payload.text.contains(payload.url))
        payload.url.trim(),
    ];
    return parts.join('\n').trim();
  }

  String? _firstHttpUrl(String text) {
    final match = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    ).firstMatch(text.trim());
    if (match == null) return null;
    return match.group(0)!.replaceAll(RegExp(r'[，。、,.)）\]】>》]+$'), '').trim();
  }

  Future<bool> _prepareComposerContentForModel(
    FileTransferModel model,
    String composerText,
  ) async {
    final text = composerText.trim();
    if (text.isEmpty) return model.hasFiles;

    final link = _firstHttpUrl(text);
    final content = await _contentPipeline.prepare(
      ContentInput(
        text: text,
        url: link,
        title: link == null ? '法布施' : '链接内容',
        sourceType: link == null ? 'composer_text' : 'composer_url',
      ),
    );
    if (content.isFailed) {
      throw StateError(content.errorMessage ?? '内容准备失败');
    }

    await model.addTextContentForSending(
      title: content.title,
      text: content.text,
      sourceKind: content.sourceUrl == null ? '文本' : '链接',
      sourceUrl: content.sourceUrl,
      previewText: content.previewText,
      replaceExisting: !model.hasFiles,
    );

    _chatInputController.clear();
    if (mounted) {
      setState(() {
        _homeChatMessages.add(
          _HomeChatMessage.contentPreview(content: content),
        );
      });
      _scrollHomeChatToBottom();
    }
    return true;
  }

  Future<void> _startPlatformPublish(FileTransferModel model) async {
    if (model.isPreparingSend || _isPublishingDraft) return;
    if (_selectedPublishPlatforms.isEmpty) {
      await _showPublishPlatformSelector();
      if (!mounted) return;
      if (_selectedPublishPlatforms.isEmpty) return;
    }

    final composerText = _chatInputController.text.trim();
    if (composerText.isEmpty && !model.hasFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先粘贴链接或输入要发布的正文。'),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    setState(() => _isPublishingDraft = true);
    DharmaPublishDraft draft;
    try {
      final prepared = await _prepareComposerContentForModel(
        model,
        composerText,
      );
      if (!prepared || !model.hasFiles) {
        throw StateError('没有可发布的内容');
      }
      draft = _dharmaPublishService.buildDraftFromModel(
        model,
        fallbackText: composerText,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPublishingDraft = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('内容准备失败: $e'), backgroundColor: Colors.red),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isPublishingDraft = false);

    final completedDraft = await _ensurePublishDraftComplete(
      draft,
      _selectedPublishPlatforms,
    );
    if (completedDraft == null || !mounted) return;

    final reviewedDraft = await _reviewPublishDraft(
      completedDraft,
      _selectedPublishPlatforms,
    );
    if (reviewedDraft == null || !mounted) return;

    setState(() => _isPublishingDraft = true);
    try {
      setState(() {
        _homeChatMessages.add(
          _HomeChatMessage(
            text: _dharmaPublishService.buildPreviewMarkdown(
              reviewedDraft,
              _selectedPublishPlatforms,
            ),
            isUser: true,
          ),
        );
      });
      _scrollHomeChatToBottom();

      final results = await _publishDraftWithBestPlatformExperience(
        reviewedDraft,
      );
      if (!mounted) return;
      setState(() {
        _homeChatMessages.add(
          _HomeChatMessage(
            text: _publishResultsMarkdown(reviewedDraft, results),
            isUser: false,
          ),
        );
        _isDharmaComposerMode = false;
        _dharmaComposerTarget = DharmaComposerTarget.global;
      });
      _scrollHomeChatToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _homeChatMessages.add(
          _HomeChatMessage(text: '发布流程遇到问题：$e', isUser: false, isError: true),
        );
      });
      _scrollHomeChatToBottom();
    } finally {
      if (mounted) setState(() => _isPublishingDraft = false);
    }
  }

  Future<List<DharmaPublishResult>> _publishDraftWithBestPlatformExperience(
    DharmaPublishDraft draft,
  ) async {
    if (_isNativeMacOrWindows) {
      final results = await Navigator.push<List<DharmaPublishResult>>(
        context,
        MaterialPageRoute(
          builder: (_) => DharmaPublishBrowserScreen(
            draft: draft,
            platforms: _selectedPublishPlatforms.toList(),
          ),
        ),
      );
      return results ??
          _selectedPublishPlatforms
              .map(
                (platform) => DharmaPublishResult(
                  platform: platform,
                  success: false,
                  message: '用户关闭了内置浏览器发布工作台',
                  steps: const ['发布流程已取消或未完成。'],
                ),
              )
              .toList();
    }

    return _dharmaPublishService.publishDraft(
      draft: draft,
      platforms: _selectedPublishPlatforms,
    );
  }

  Future<DharmaPublishDraft?> _ensurePublishDraftComplete(
    DharmaPublishDraft draft,
    Set<DharmaPublishPlatform> platforms,
  ) async {
    if (_dharmaPublishService.missingFields(draft, platforms).isEmpty) {
      return draft;
    }
    return _showEditDraftDialog(
      draft,
      title: '补全发布信息',
      helperText: '检测到标题或正文不完整。可以自己输入，也可以使用 AI 生成/润色。',
    );
  }

  Future<DharmaPublishDraft?> _reviewPublishDraft(
    DharmaPublishDraft draft,
    Set<DharmaPublishPlatform> platforms,
  ) async {
    var current = draft;
    while (mounted) {
      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('发布预览'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: MarkdownBody(
                data: _dharmaPublishService.buildPreviewMarkdown(
                  current,
                  platforms,
                ),
                selectable: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'cancel'),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'edit'),
              child: const Text('自己修改'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'ai'),
              child: const Text('AI 修改'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'publish'),
              child: const Text('发布'),
            ),
          ],
        ),
      );

      if (action == 'publish') return current;
      if (action == 'edit') {
        final edited = await _showEditDraftDialog(current);
        if (edited != null) current = edited;
        continue;
      }
      if (action == 'ai') {
        final requirement = await _askDraftRevisionRequirement();
        if (requirement == null) continue;
        final body = await _generateRevisedBody(current, requirement);
        current = current.copyWith(
          title: current.title.trim().isEmpty
              ? await _generateTitleForDraft(current)
              : current.title,
          body: body,
        );
        continue;
      }
      return null;
    }
    return null;
  }

  Future<DharmaPublishDraft?> _showEditDraftDialog(
    DharmaPublishDraft draft, {
    String title = '修改发布草稿',
    String helperText = '请确认标题、正文、标签和来源链接。',
  }) async {
    final titleController = TextEditingController(text: draft.title);
    final bodyController = TextEditingController(text: draft.body);
    final tagController = TextEditingController(text: draft.tags.join(' '));
    final sourceController = TextEditingController(text: draft.sourceUrl);
    bool generating = false;

    final result = await showDialog<DharmaPublishDraft>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> generateTitle() async {
              setDialogState(() => generating = true);
              final generated = await _generateTitleForDraft(
                draft.copyWith(body: bodyController.text),
              );
              titleController.text = generated;
              setDialogState(() => generating = false);
            }

            Future<void> polishBody() async {
              setDialogState(() => generating = true);
              final revised = await _generateRevisedBody(
                draft.copyWith(
                  title: titleController.text,
                  body: bodyController.text,
                ),
                '润色为适合自媒体发布的温和、清晰、尊重平台规则的文案',
              );
              bodyController.text = revised;
              setDialogState(() => generating = false);
            }

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(helperText),
                      const SizedBox(height: 14),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: '标题',
                          suffixIcon: IconButton(
                            tooltip: 'AI 生成标题',
                            onPressed: generating ? null : generateTitle,
                            icon: const Icon(Icons.auto_awesome),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bodyController,
                        minLines: 6,
                        maxLines: 12,
                        decoration: InputDecoration(
                          labelText: '正文',
                          alignLabelWithHint: true,
                          suffixIcon: IconButton(
                            tooltip: 'AI 润色正文',
                            onPressed: generating ? null : polishBody,
                            icon: const Icon(Icons.auto_fix_high),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tagController,
                        decoration: const InputDecoration(
                          labelText: '标签（空格分隔）',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: sourceController,
                        decoration: const InputDecoration(labelText: '来源链接'),
                      ),
                      if (generating) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: generating
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: generating
                      ? null
                      : () {
                          Navigator.pop(
                            dialogContext,
                            draft.copyWith(
                              title: titleController.text.trim(),
                              body: bodyController.text.trim(),
                              sourceUrl: sourceController.text.trim(),
                              tags: tagController.text
                                  .split(RegExp(r'[\s,，#]+'))
                                  .map((tag) => tag.trim())
                                  .where((tag) => tag.isNotEmpty)
                                  .toSet()
                                  .toList(),
                            ),
                          );
                        },
                  child: const Text('继续'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    bodyController.dispose();
    tagController.dispose();
    sourceController.dispose();
    return result;
  }

  Future<String?> _askDraftRevisionRequirement() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('输入 AI 修改要求'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '例如：更适合小红书，语气更温和，保留来源链接，控制在 500 字以内。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('生成'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<String> _generateTitleForDraft(DharmaPublishDraft draft) async {
    final prompt = [
      '请为下面法布施/公益分享内容生成一个适合自媒体发布的中文标题。',
      '要求：只返回标题，不超过 28 个字，不夸大，不制造焦虑。',
      '',
      draft.bodyPreview,
    ].join('\n');
    final ai = await _askDachengAi(prompt);
    final title = ai?.split('\n').first.trim();
    if (title != null && title.isNotEmpty) return title;
    return _dharmaPublishService.suggestTitle(draft);
  }

  Future<String> _generateRevisedBody(
    DharmaPublishDraft draft,
    String requirement,
  ) async {
    final prompt = [
      '请根据要求修改下面的发布草稿。',
      '要求：$requirement',
      '请直接返回可发布正文，不要解释。',
      '',
      '标题：${draft.title}',
      '正文：',
      draft.body,
      if (draft.sourceUrl.trim().isNotEmpty) '来源链接：${draft.sourceUrl}',
    ].join('\n');
    final ai = await _askDachengAi(prompt);
    if (ai != null && ai.trim().isNotEmpty) return ai.trim();
    return _dharmaPublishService.polishBody(draft);
  }

  Future<String?> _askDachengAi(String prompt) async {
    try {
      final authModel = Provider.of<AuthModel?>(context, listen: false);
      final result = await _dachengAiService.sendChat(
        message: prompt,
        model: _selectedDesktopModelId,
        client: _desktopAiClientContext(),
        token: authModel?.authToken,
        username: authModel?.currentUser?.username,
        isMember: authModel?.hasPermission('premium') ?? false,
      );
      final message = result.message.trim();
      return message.isEmpty ? null : message;
    } catch (e) {
      debugPrint('发布草稿 AI 生成失败，使用本地规则兜底: $e');
      return null;
    }
  }

  String _publishResultsMarkdown(
    DharmaPublishDraft draft,
    List<DharmaPublishResult> results,
  ) {
    final success = results.where((result) => result.success).length;
    final lines = <String>[
      '### 发布流程完成',
      '',
      '标题：${draft.title.trim().isEmpty ? "未命名" : draft.title.trim()}',
      '平台：$success / ${results.length} 个入口已拉起',
      '',
      for (final result in results) ...[
        result.success
            ? '- ✅ ${result.platform.info.label}：${result.message}'
            : '- ⚠️ ${result.platform.info.label}：${result.message}',
        for (final step in result.steps) '  - $step',
        if (result.screenshotPaths.isNotEmpty) '  - 浏览器截图（折叠展示）',
        for (var i = 0; i < result.screenshotPaths.length; i++)
          '    - 截图 ${i + 1}: ${result.screenshotPaths[i]}',
      ],
      '',
      '草稿内容已复制到剪贴板；若平台要求登录、验证码或最终发布确认，请在打开的页面/App 中完成。',
    ];
    return lines.join('\n');
  }

  Future<void> _showRegionSelector(FileTransferModel model) async {
    final authModel = Provider.of<AuthModel?>(context, listen: false);
    final hasPremiumAccess = authModel?.hasPermission('premium') ?? false;
    final selectedCodes = model.countryList.toSet();
    var localField = model.isFieldEnergyMode;
    var localLoopback = hasPremiumAccess && model.isLocalLoopbackEnabled;
    var query = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final normalizedQuery = query.trim().toLowerCase();
            final countries = _countryOptions.where((entry) {
              if (normalizedQuery.isEmpty) return true;
              return entry.key.toLowerCase().contains(normalizedQuery) ||
                  entry.value.toLowerCase().contains(normalizedQuery);
            }).toList();
            final canApply =
                selectedCodes.isNotEmpty || localField || localLoopback;

            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
                ),
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                decoration: const BoxDecoration(
                  color: Color(0xFF202020),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '地区',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('取消'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (value) {
                        setSheetState(() => query = value);
                      },
                      style: const TextStyle(color: Colors.white),
                      cursorColor: AppTheme.primaryColor,
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white54,
                        ),
                        hintText: '搜索国家或代码',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        children: [
                          _RegionCheckTile(
                            icon: Icons.public,
                            title: '全球',
                            subtitle: '全部国家发送',
                            selected: selectedCodes.contains('ALL'),
                            onChanged: (selected) {
                              setSheetState(() {
                                if (selected) {
                                  selectedCodes
                                    ..clear()
                                    ..add('ALL');
                                } else {
                                  selectedCodes.remove('ALL');
                                }
                              });
                            },
                          ),
                          _RegionCheckTile(
                            icon: Icons.wifi_tethering,
                            title: '本地场能',
                            subtitle: '通过本机热点向周围广播',
                            selected: localField,
                            onChanged: (selected) {
                              setSheetState(() => localField = selected);
                            },
                          ),
                          _RegionCheckTile(
                            icon: hasPremiumAccess
                                ? Icons.sync_alt
                                : Icons.lock_outline,
                            title: '本地转经轮',
                            subtitle: hasPremiumAccess
                                ? '不可思议扬升能量场'
                                : '会员可开启不可思议扬升能量场',
                            selected: localLoopback,
                            onChanged: (selected) {
                              if (selected && !hasPremiumAccess) {
                                _showLoopbackMembershipPrompt();
                                return;
                              }
                              setSheetState(() => localLoopback = selected);
                            },
                          ),
                          const Divider(color: Colors.white12, height: 18),
                          ...countries.map(
                            (entry) => _RegionCheckTile(
                              title: '${entry.value} ${entry.key}',
                              subtitle: '国家发送节点',
                              selected: selectedCodes.contains(entry.key),
                              onChanged: (selected) {
                                setSheetState(() {
                                  selectedCodes.remove('ALL');
                                  if (selected) {
                                    selectedCodes.add(entry.key);
                                  } else {
                                    selectedCodes.remove(entry.key);
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canApply
                            ? () async {
                                final finalCodes = selectedCodes.toList();
                                model.setCountryList(finalCodes);
                                model.setGlobalSendEnabled(
                                  finalCodes.isNotEmpty,
                                );
                                await model.setFieldEnergyMode(localField);
                                await _setLocalLoopbackEnabled(
                                  model,
                                  localLoopback,
                                );
                                if (!sheetContext.mounted) return;
                                Navigator.pop(sheetContext);

                                if (!mounted) return;
                                if (model.needsHotspotGuide) {
                                  _showHotspotGuideDialog(context);
                                  model.clearHotspotGuide();
                                }
                                setState(() {});
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.white12,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('完成'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _sendAiChatFromComposer() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty || _isAiGenerating) return;

    HapticFeedback.lightImpact();
    final requestSerial = ++_aiRequestSerial;
    final requestWatch = Stopwatch()..start();
    _diagHomeAi(
      'send.start',
      data: {
        'requestSerial': requestSerial,
        'messageLength': text.length,
        'activeConversationId': _activeConversationId,
      },
    );
    final authModel = Provider.of<AuthModel?>(context, listen: false);
    await _aiStreamSubscription?.cancel();
    _aiStreamSubscription = null;
    _chatInputController.clear();
    setState(() {
      _homeChatMessages.add(_HomeChatMessage(text: text, isUser: true));
      _isAiGenerating = true;
      _streamingAiText = '';
      _aiActivityText = '正在思考';
    });
    _diagHomeAi('send.ui-thinking', data: {'requestSerial': requestSerial});
    _scrollHomeChatToBottom(force: true);

    try {
      final stepLines = <String>[];
      var finalText = '';
      String? latestConversationId = _activeConversationId;
      var eventCount = 0;
      var deltaCount = 0;

      await for (final event in _dachengAiService.sendChatStream(
        message: text,
        conversationId: _activeConversationId,
        model: _selectedDesktopModelId,
        client: _desktopAiClientContext(),
        token: authModel?.authToken,
        username: authModel?.currentUser?.username,
        isMember: authModel?.hasPermission('premium') ?? false,
      )) {
        if (!mounted || requestSerial != _aiRequestSerial) return;
        eventCount++;

        if (event.conversationId != null && event.conversationId!.isNotEmpty) {
          latestConversationId = event.conversationId;
        }

        if (event.isStep) {
          _diagHomeAi(
            'send.event-step',
            data: {
              'requestSerial': requestSerial,
              'eventCount': eventCount,
              'textLength': event.text.length,
              'title': event.raw['title']?.toString(),
              'message': event.raw['message']?.toString(),
            },
          );
          final visibleStep = _visibleAiStepLabel(event);
          if (visibleStep != null) {
            stepLines
              ..clear()
              ..add(visibleStep);
          }
        } else if (event.isDelta) {
          deltaCount++;
          if (deltaCount == 1) {
            _diagHomeAi(
              'send.first-delta',
              data: {
                'requestSerial': requestSerial,
                'elapsedMs': requestWatch.elapsedMilliseconds,
                'deltaLength': event.text.length,
              },
            );
          }
          finalText += event.text;
        } else if (event.isDone) {
          _diagHomeAi(
            'send.event-done',
            data: {
              'requestSerial': requestSerial,
              'elapsedMs': requestWatch.elapsedMilliseconds,
              'eventCount': eventCount,
              'deltaCount': deltaCount,
              'finalLength': finalText.length,
              'rawMessageLength': event.raw['message']?.toString().length,
            },
          );
          latestConversationId = event.conversationId ?? latestConversationId;
          finalText = (event.raw['message'] ?? finalText).toString();
        } else if (event.isError) {
          _diagHomeAi(
            'send.event-error',
            data: {'requestSerial': requestSerial, 'text': event.text},
          );
          throw StateError(event.text.isEmpty ? '大乘 AI 生成失败' : event.text);
        }

        setState(() {
          _activeConversationId = latestConversationId;
          _aiActivityText = stepLines.isNotEmpty
              ? stepLines.last
              : (finalText.trim().isEmpty ? '正在思考' : '正在生成');
          _streamingAiText = finalText;
        });
        _scrollHomeChatToBottom();
      }

      if (!mounted || requestSerial != _aiRequestSerial) return;
      _diagHomeAi(
        'send.complete',
        data: {
          'requestSerial': requestSerial,
          'elapsedMs': requestWatch.elapsedMilliseconds,
          'finalLength': finalText.trim().length,
          'deltaCount': deltaCount,
          'eventCount': eventCount,
        },
      );
      setState(() {
        _activeConversationId = latestConversationId;
        if (finalText.trim().isNotEmpty) {
          _homeChatMessages.add(
            _HomeChatMessage(text: finalText.trim(), isUser: false),
          );
        }
        _streamingAiText = '';
        _aiActivityText = '';
        _isAiGenerating = false;
      });
      _scrollHomeChatToBottom(force: true);
      unawaited(_loadRemoteConversations());
    } catch (e, stackTrace) {
      if (!mounted || requestSerial != _aiRequestSerial) return;
      _diagHomeAi(
        'send.failed',
        data: {
          'requestSerial': requestSerial,
          'elapsedMs': requestWatch.elapsedMilliseconds,
        },
        error: e,
        stackTrace: stackTrace,
      );
      setState(() {
        _homeChatMessages.add(
          _HomeChatMessage(
            text: '大乘 AI 生成失败: ${_friendlyErrorMessage(e)}',
            isUser: false,
            isError: true,
          ),
        );
        _streamingAiText = '';
        _aiActivityText = '';
        _isAiGenerating = false;
      });
      _scrollHomeChatToBottom(force: true);
    }
  }

  String _friendlyErrorMessage(Object error) {
    final text = error.toString().trim();
    const badStatePrefix = 'Bad state: ';
    const exceptionPrefix = 'Exception: ';
    if (text.startsWith(badStatePrefix)) {
      return text.substring(badStatePrefix.length).trim();
    }
    if (text.startsWith(exceptionPrefix)) {
      return text.substring(exceptionPrefix.length).trim();
    }
    return text.isEmpty ? '请求失败，请稍后重试。' : text;
  }

  void _stopAiGeneration() {
    _diagHomeAi(
      'send.stop-requested',
      data: {
        'requestSerial': _aiRequestSerial,
        'hasStreamingText': _streamingAiText.trim().isNotEmpty,
      },
    );
    _aiRequestSerial++;
    _aiStreamSubscription?.cancel();
    _aiStreamSubscription = null;
    if (!mounted) return;
    setState(() {
      if (_streamingAiText.trim().isNotEmpty) {
        _homeChatMessages.add(
          _HomeChatMessage(text: _streamingAiText, isUser: false),
        );
      }
      _streamingAiText = '';
      _aiActivityText = '';
      _isAiGenerating = false;
    });
  }

  String? _visibleAiStepLabel(DachengAiStreamEvent event) {
    final title = (event.raw['title'] ?? '').toString().trim();
    final message = (event.raw['message'] ?? event.text).toString().trim();
    final combined = [
      title,
      message,
    ].where((part) => part.isNotEmpty).join(' ');
    if (combined.isEmpty) return null;
    if (RegExp(r'VPS|后端|DeepSeek|OpenAI-compatible|直连|连接').hasMatch(combined)) {
      return null;
    }
    if (RegExp(r'执行命令|调用工具|搜索|下载|资源|整理|计划|文件|MCP|工具').hasMatch(combined)) {
      return title.isNotEmpty ? title : message;
    }
    return null;
  }

  void _diagHomeAi(
    String message, {
    Map<String, Object?> data = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    unawaited(
      DiagnosticLogService.instance.log(
        'home.ai',
        message,
        data: data,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  void _scrollHomeChatToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_homeChatScrollController.hasClients) return;
      final position = _homeChatScrollController.position;
      if (!force && position.maxScrollExtent - position.pixels > 180) {
        return;
      }
      _homeChatScrollController.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadOpenClawHomeStatus({required bool probeOpenClaw}) async {
    if (!AiBackendPolicy.isDesktopNative) return;
    if (mounted) setState(() => _isOpenClawPanelLoading = true);
    try {
      final values = await Future.wait<dynamic>([
        AppSettings.getOpenClawRemoteGatewayUrl(),
        OpenClawRuntime.instance
            .getStatus(probe: probeOpenClaw)
            .timeout(const Duration(seconds: 8)),
        DesktopControlBridge.instance.getStatus().timeout(
          const Duration(seconds: 5),
        ),
        DesktopControlBridge.instance.pendingConfirmations().timeout(
          const Duration(seconds: 5),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _openClawRemoteGatewayUrl = (values[0] as String).trim();
        _openClawStatus = values[1] as OpenClawRuntimeStatus;
        _desktopControlStatus = values[2] as DesktopControlBridgeStatus;
        _desktopControlPending =
            values[3] as List<DesktopControlPendingConfirmation>;
        _isOpenClawPanelLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _openClawStatus = OpenClawRuntimeStatus(
          state: OpenClawRuntimeState.failed,
          message: 'OpenClaw 状态检测失败：$error',
          checkedAt: DateTime.now(),
        );
        _desktopControlPending = const [];
        _isOpenClawPanelLoading = false;
      });
    }
  }

  Future<void> _refreshOpenClawHomeStatus() {
    return _loadOpenClawHomeStatus(probeOpenClaw: true);
  }

  Future<void> _restartOpenClawFromHome() async {
    if (!AiBackendPolicy.isDesktopNative || _isRestartingOpenClaw) return;
    setState(() => _isRestartingOpenClaw = true);
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
      _isRestartingOpenClaw = false;
    });
    unawaited(_loadOpenClawHomeStatus(probeOpenClaw: true));
    _showHomeSnack(
      status.isHealthy ? '本机 OpenClaw 已启动' : status.message,
      ok: status.isHealthy,
    );
  }

  Future<void> _runOpenClawHomeCliAction(
    String label,
    Future<OpenClawCliResult> Function() action,
  ) async {
    if (!AiBackendPolicy.isDesktopNative || _isRunningOpenClawAction) return;
    setState(() => _isRunningOpenClawAction = true);
    OpenClawCliResult? result;
    Object? error;
    try {
      result = await action();
    } catch (err) {
      error = err;
      debugPrint('首页 OpenClaw $label 失败: $err');
    }
    if (!mounted) return;
    setState(() => _isRunningOpenClawAction = false);
    if (result == null) {
      _showHomeSnack('$label 失败：$error', ok: false);
      return;
    }
    await _showOpenClawCliResult(label, result);
    unawaited(_loadOpenClawHomeStatus(probeOpenClaw: true));
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

  Future<void> _editOpenClawHomeRemoteGatewayUrl() async {
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
            helperText: '移动端、微信、小程序从公网远程连接这台电脑',
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
    await AppSettings.setOpenClawRemoteGatewayUrl(value.trim());
    if (!mounted) return;
    setState(() => _openClawRemoteGatewayUrl = value.trim());
    _showHomeSnack('已保存远程入口，重启本机 AI 后生效');
  }

  Future<void> _createOpenClawHomeMobilePairingCode() async {
    if (_openClawRemoteGatewayUrl.trim().isEmpty) {
      await _editOpenClawHomeRemoteGatewayUrl();
      if (_openClawRemoteGatewayUrl.trim().isEmpty) return;
    }
    await _runOpenClawHomeCliAction(
      '移动端配对码',
      () => OpenClawRuntime.instance.createMobilePairingCode(remote: true),
    );
  }

  Future<void> _installOpenClawHomeWeChatPlugin() {
    return _runOpenClawHomeCliAction(
      '安装微信插件',
      OpenClawRuntime.instance.installWeChatPlugin,
    );
  }

  Future<void> _loginOpenClawHomeWeChat() {
    return _runOpenClawHomeCliAction(
      '微信扫码登录',
      OpenClawRuntime.instance.loginWeChat,
    );
  }

  Future<void> _inspectOpenClawHomeChannels() {
    return _runOpenClawHomeCliAction(
      'OpenClaw 渠道状态',
      OpenClawRuntime.instance.inspectChannels,
    );
  }

  Future<void> _prepareHomeChromeConnector() async {
    if (!AiBackendPolicy.isDesktopNative || _isPreparingChromeConnector) {
      return;
    }
    setState(() => _isPreparingChromeConnector = true);
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
    setState(() => _isPreparingChromeConnector = false);
    unawaited(_loadOpenClawHomeStatus(probeOpenClaw: true));
    _showHomeSnack(
      error != null
          ? 'Chrome 连接器准备失败：$error'
          : path == null
          ? '当前构建未启用 Chrome 连接器'
          : 'Chrome 连接器目录已打开',
      ok: error == null,
    );
  }

  Future<void> _startDesktopBridgeFromHome() async {
    try {
      final status = await DesktopControlBridge.instance.ensureStarted();
      final pending = await DesktopControlBridge.instance
          .pendingConfirmations()
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _desktopControlStatus = status;
        _desktopControlPending = pending;
      });
      _showHomeSnack(status.message, ok: status.desktopControlAvailable);
    } catch (error) {
      if (!mounted) return;
      _showHomeSnack('桌面工具启动失败：$error', ok: false);
    }
  }

  Future<void> _approveHomeDesktopControlRequest(String id) async {
    final item = await DesktopControlBridge.instance.approvePendingRequest(id);
    await _loadOpenClawHomeStatus(probeOpenClaw: true);
    if (!mounted) return;
    _showHomeSnack(
      item == null ? '确认请求已失效' : '已允许该动作，工具可继续执行',
      ok: item != null,
    );
  }

  Future<void> _rejectHomeDesktopControlRequest(String id) async {
    final item = await DesktopControlBridge.instance.rejectPendingRequest(id);
    await _loadOpenClawHomeStatus(probeOpenClaw: true);
    if (!mounted) return;
    _showHomeSnack(item == null ? '确认请求已失效' : '已拒绝该动作', ok: false);
  }

  Future<void> _requestHomeDesktopPermission({
    required bool screenRecording,
  }) async {
    final result = screenRecording
        ? await DesktopControlBridge.instance.requestScreenRecordingPermission()
        : await DesktopControlBridge.instance.requestAccessibilityPermission();
    await _loadOpenClawHomeStatus(probeOpenClaw: true);
    if (!mounted) return;
    _showHomeSnack(result['message']?.toString() ?? '已打开系统权限请求');
  }

  Future<void> _copyDiagnosticLogTailFromHome() async {
    final path = await DiagnosticLogService.instance.logFilePath();
    final tail = await DiagnosticLogService.instance.tail(maxLines: 400);
    await Clipboard.setData(
      ClipboardData(text: '诊断日志路径: ${path ?? '无持久化日志路径'}\n\n$tail'),
    );
    if (!mounted) return;
    _showHomeSnack(path == null ? '已复制当前诊断日志内容' : '已复制诊断日志内容和路径');
  }

  void _showHomeSnack(String text, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: ok ? Colors.green : Colors.redAccent,
      ),
    );
  }

  Future<void> _setLocalLoopbackEnabled(
    FileTransferModel model,
    bool enabled,
  ) async {
    if (!enabled) {
      model.setLocalLoopbackEnabled(false);
      return;
    }

    final authModel = Provider.of<AuthModel?>(context, listen: false);
    final hasPremiumAccess = authModel?.hasPermission('premium') ?? false;
    if (!hasPremiumAccess) {
      model.setLocalLoopbackEnabled(false);
      _showLoopbackMembershipPrompt();
      return;
    }

    model.setLocalLoopbackEnabled(true);
  }

  void _showLoopbackMembershipPrompt() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('不可思议扬升能量场是会员功能，开通会员后即可开启。'),
        backgroundColor: Colors.black87,
        action: SnackBarAction(
          label: '去开通',
          textColor: AppTheme.primaryColor,
          onPressed: () {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MembershipScreen()),
            );
          },
        ),
      ),
    );
  }

  IconData _contentIcon(String kind) {
    switch (kind) {
      case '链接':
        return Icons.link;
      case '文本':
        return Icons.edit_note;
      case '本机文件':
        return Icons.folder_open;
      case '素材文件':
        return Icons.inventory_2;
      case '3D佛像素材':
      case '禅室佛像素材':
        return Icons.self_improvement;
      default:
        return Icons.library_books;
    }
  }

  void _showHotspotGuideDialog(BuildContext context) {
    String title;
    List<String> steps;
    String tip;

    if (kIsWeb) {
      return;
    } else if (_isNativeIos) {
      title = '开启个人热点';
      steps = [
        '1. 点击下方"前往设置"按钮',
        '2. 找到"个人热点"选项',
        '3. 开启"允许其他人加入"',
        '4. 返回本应用开始发送',
      ];
      tip = '💡 开启热点后，经文能量将通过 Wi-Fi 信号向周围空间广播';
    } else if (_isNativeAndroid) {
      title = '开启便携式热点';
      steps = [
        '1. 点击下方"前往设置"按钮',
        '2. 找到"热点与网络共享"或"便携式热点"',
        '3. 开启"便携式 WLAN 热点"',
        '4. 返回本应用开始发送',
      ];
      tip = '💡 开启热点后，经文能量将通过 Wi-Fi 信号向周围空间广播';
    } else if (_isNativeMacOs) {
      title = '开启互联网共享';
      steps = [
        '1. 点击下方"前往设置"按钮',
        '2. 在"共享"面板中找到"互联网共享"',
        '3. 选择"Wi-Fi"作为共享方式',
        '4. 勾选启用"互联网共享"',
        '5. 返回本应用开始发送',
      ];
      tip = '💡 开启共享后，经文能量将通过 Wi-Fi 信号向周围空间广播';
    } else {
      title = '开启热点';
      steps = ['1. 打开系统设置', '2. 找到网络或热点设置', '3. 开启 Wi-Fi 热点功能', '4. 返回本应用开始发送'];
      tip = '💡 开启热点后，经文能量将通过 Wi-Fi 信号向周围空间广播';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.wifi_tethering, color: Colors.purple, size: 28),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '请按以下步骤开启热点：',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...steps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  step,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.purple,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(color: Colors.purple[200], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后设置', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              final model = Provider.of<FileTransferModel>(
                context,
                listen: false,
              );
              model.setFieldEnergyMode(true);
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('前往设置'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSelectedContentPreview(FileTransferModel model) async {
    final text = model.selectedContentPreviewText?.trim();
    if (text == null || text.isEmpty) return;

    final title = model.selectedContentTitle.isEmpty
        ? '已读取内容'
        : model.selectedContentTitle;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: SelectableText(
              model.selectedContentSourceUrl == null
                  ? text
                  : '来源链接: ${model.selectedContentSourceUrl}\n\n$text',
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(
                dialogContext,
              ).showSnackBar(const SnackBar(content: Text('内容已复制')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('复制'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showBuddhaAssetMessage(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<bool> _ensureBuddhaAssetUnlocked() async {
    final authModel = Provider.of<AuthModel?>(context, listen: false);
    final token = authModel?.authToken;
    if (authModel == null || !authModel.isLoggedIn || token == null) {
      _showBuddhaAssetMessage('请先登录后再解锁3D佛像素材', color: Colors.orange);
      return false;
    }

    if (_buddhaAssetUnlocked == true) {
      return true;
    }

    final unlocked = await _checkBuddhaAssetEntitlement(authModel);
    if (unlocked) return true;

    return await _showBuddhaAssetPaywall(token);
  }

  Future<bool> _checkBuddhaAssetEntitlement(AuthModel authModel) async {
    final token = authModel.authToken;
    if (token == null) return false;

    final result = await _membershipService.checkPurchaseEntitlement(
      token,
      AppConfig.zenBuddhaAssetProductId,
    );
    if (result['success'] == true) {
      final unlocked = result['unlocked'] == true;
      if (mounted) {
        setState(() => _buddhaAssetUnlocked = unlocked);
      }
      return unlocked;
    }

    return _buddhaAssetUnlocked == true;
  }

  Future<bool> _showBuddhaAssetPaywall(String token) async {
    final unlocked = await showDialog<bool>(
      context: context,
      barrierDismissible: !_isPurchasingBuddhaAsset,
      builder: (dialogContext) => AlertDialog(
        title: Text('解锁${AppConfig.zenBuddhaAssetDisplayName}'),
        content: const Text('付费后可在首页选择3D佛像素材，并加入全球发送内容。'),
        actions: [
          TextButton(
            onPressed: _isPurchasingBuddhaAsset
                ? null
                : () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.lock_open, size: 18),
            label: Text('${AppConfig.zenBuddhaAssetPriceLabel} 解锁'),
            onPressed: _isPurchasingBuddhaAsset
                ? null
                : () async {
                    final navigator = Navigator.of(dialogContext);
                    final success = AppleIapService.isAppleIapPlatform
                        ? await _purchaseBuddhaAssetWithApple(token)
                        : await _purchaseBuddhaAssetWithAlipay(token);
                    if (success && navigator.mounted) {
                      navigator.pop(true);
                    }
                  },
          ),
        ],
      ),
    );

    return unlocked == true;
  }

  Future<bool> _purchaseBuddhaAssetWithApple(String token) async {
    if (!AppleIapService.isAppleIapPlatform) {
      _showBuddhaAssetMessage('当前平台不支持 Apple 内购', color: Colors.red);
      return false;
    }

    if (mounted) setState(() => _isPurchasingBuddhaAsset = true);
    final completer = Completer<bool>();
    final previousSuccess = _appleIapService.onPurchaseSuccess;
    final previousError = _appleIapService.onPurchaseError;

    try {
      final available = await _appleIapService.initialize();
      if (!available) {
        _showBuddhaAssetMessage('Apple 内购暂不可用，请稍后再试', color: Colors.red);
        return false;
      }

      _appleIapService.onPurchaseSuccess = (purchase) async {
        if (purchase.productID != AppConfig.zenBuddhaAssetProductId) {
          previousSuccess?.call(purchase);
          return;
        }

        final transactionId = _appleIapService.getTransactionId(purchase);
        if (transactionId == null) {
          _showBuddhaAssetMessage('Apple 交易号为空，无法完成解锁', color: Colors.red);
          if (!completer.isCompleted) completer.complete(false);
          return;
        }

        final result = await _membershipService.verifyAppleReceipt(
          token,
          transactionId,
          purchase.productID,
        );
        final unlocked =
            result['success'] == true &&
            (result['unlocked'] == true ||
                result['productType'] == 'asset_unlock');

        if (unlocked) {
          if (mounted) setState(() => _buddhaAssetUnlocked = true);
          _showBuddhaAssetMessage('3D佛像素材已解锁', color: Colors.green);
        } else {
          _showBuddhaAssetMessage(
            result['message'] ?? 'Apple 内购验证失败',
            color: Colors.red,
          );
        }

        if (!completer.isCompleted) completer.complete(unlocked);
      };

      _appleIapService.onPurchaseError = (error) {
        _showBuddhaAssetMessage(error, color: Colors.red);
        if (!completer.isCompleted) completer.complete(false);
        previousError?.call(error);
      };

      final started = await _appleIapService.purchase(
        AppConfig.zenBuddhaAssetProductId,
      );
      if (!started && !completer.isCompleted) {
        completer.complete(false);
      }

      return await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          _showBuddhaAssetMessage(
            'Apple 内购结果超时，请稍后检查解锁状态',
            color: Colors.orange,
          );
          return false;
        },
      );
    } finally {
      _appleIapService.onPurchaseSuccess = previousSuccess;
      _appleIapService.onPurchaseError = previousError;
      if (mounted) setState(() => _isPurchasingBuddhaAsset = false);
    }
  }

  Future<bool> _purchaseBuddhaAssetWithAlipay(String token) async {
    if (!_isNativeAndroid) {
      return _purchaseBuddhaAssetWithAlipayWeb(token);
    }

    if (mounted) setState(() => _isPurchasingBuddhaAsset = true);
    try {
      final initResult = await _alipayService.initAlipay();
      if (initResult['success'] != true) {
        _showBuddhaAssetMessage(
          initResult['message'] ?? '请先安装支付宝后再解锁',
          color: Colors.red,
        );
        return false;
      }

      final orderResult = await _membershipService.createAlipayOrder(
        token,
        AppConfig.zenBuddhaAssetProductId,
      );
      if (orderResult['success'] != true) {
        _showBuddhaAssetMessage(
          orderResult['message'] ?? '创建支付宝订单失败',
          color: Colors.red,
        );
        return false;
      }

      final orderId = orderResult['orderId']?.toString();
      final orderString = orderResult['orderString']?.toString();
      if (orderId == null ||
          orderId.isEmpty ||
          orderString == null ||
          orderString.isEmpty) {
        _showBuddhaAssetMessage('支付宝订单参数不完整', color: Colors.red);
        return false;
      }

      final payResult = await _alipayService.payWithAlipay(orderString);
      final resultStatus = payResult['resultStatus']?.toString();
      if (payResult['success'] == true ||
          resultStatus == '8000' ||
          resultStatus == '6004') {
        return await _waitForBuddhaAssetAlipayUnlock(token, orderId);
      }

      _showBuddhaAssetMessage(
        payResult['message'] ?? '支付宝支付未完成',
        color: Colors.orange,
      );
      return false;
    } finally {
      if (mounted) setState(() => _isPurchasingBuddhaAsset = false);
    }
  }

  Future<bool> _purchaseBuddhaAssetWithAlipayWeb(String token) async {
    if (mounted) setState(() => _isPurchasingBuddhaAsset = true);
    try {
      final orderResult = await _membershipService.createAlipayWebOrder(
        token,
        AppConfig.zenBuddhaAssetProductId,
      );
      if (orderResult['success'] != true) {
        _showBuddhaAssetMessage(
          orderResult['message'] ?? '创建支付宝网页订单失败',
          color: Colors.red,
        );
        return false;
      }

      final orderId = orderResult['orderId']?.toString();
      final paymentUrl = orderResult['paymentUrl']?.toString();
      if (orderId == null ||
          orderId.isEmpty ||
          paymentUrl == null ||
          paymentUrl.isEmpty) {
        _showBuddhaAssetMessage('支付宝网页支付参数不完整', color: Colors.red);
        return false;
      }

      final launchResult = await _alipayService.payWithAlipayWeb(paymentUrl);
      if (launchResult['success'] != true) {
        _showBuddhaAssetMessage(
          launchResult['message'] ?? '无法打开支付宝网页支付',
          color: Colors.red,
        );
        return false;
      }

      _showBuddhaAssetMessage('已打开支付宝网页支付，请在浏览器完成付款', color: Colors.green);
      return await _waitForBuddhaAssetAlipayUnlock(token, orderId);
    } finally {
      if (mounted) setState(() => _isPurchasingBuddhaAsset = false);
    }
  }

  Future<bool> _waitForBuddhaAssetAlipayUnlock(
    String token,
    String orderId,
  ) async {
    const maxRetries = 12;
    const retryDelay = Duration(seconds: 3);

    for (var i = 0; i < maxRetries; i++) {
      await Future.delayed(retryDelay);
      final orderStatus = await _membershipService.queryAlipayOrderStatus(
        token,
        orderId,
      );

      if (orderStatus['status'] == 'PAID') {
        if (!mounted) return false;
        final authModel = Provider.of<AuthModel?>(context, listen: false);
        if (authModel == null) return false;
        final unlocked = await _checkBuddhaAssetEntitlement(authModel);
        if (unlocked) {
          _showBuddhaAssetMessage('3D佛像素材已解锁', color: Colors.green);
          return true;
        }
      }
    }

    _showBuddhaAssetMessage('支付状态确认超时，请稍后重新进入首页检查', color: Colors.orange);
    return false;
  }

  bool _isBuddhaAssetSelected(FileTransferModel model) {
    return model.selectedContentKind == AppConfig.zenBuddhaAssetDisplayName ||
        model.selectedContentKind == '禅室佛像素材' ||
        model.currentSendingScripture == AppConfig.zenBuddhaAssetDisplayName ||
        model.currentSendingScripture == '禅室佛像素材';
  }

  bool _looksLikeHttpUrl(String text) {
    final uri = Uri.tryParse(text.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  String _sendContentTitle(FileTransferModel model, String composerText) {
    if (model.selectedContentTitle.trim().isNotEmpty) {
      return model.selectedContentTitle.trim();
    }
    final text = composerText.trim();
    if (text.isNotEmpty) {
      return _looksLikeHttpUrl(text) ? text : '法布施文字';
    }
    final file = model.selectedFile;
    return file?.name ?? '法布施内容';
  }

  String _formatElapsed(Duration duration) {
    if (duration.inMinutes >= 1) {
      final seconds = duration.inSeconds % 60;
      return '${duration.inMinutes}分$seconds秒';
    }
    return '${duration.inSeconds.clamp(1, 999)}秒';
  }

  void _appendGlobalSendResult(FileTransferModel model) {
    final successCount = model.countryStatuses
        .where((status) => status.status == SendStatus.success)
        .length;
    final completedCount = model.globalSentCount > 0
        ? model.globalSentCount
        : successCount;
    final elapsed = _sendStartedAt == null
        ? null
        : _formatElapsed(DateTime.now().difference(_sendStartedAt!));
    final title = _activeSendTitle.isEmpty ? '法布施内容' : _activeSendTitle;
    final region = _activeSendRegion.isEmpty
        ? _regionSummary(model)
        : _activeSendRegion;

    String text;
    if (model.status == TransferStatus.completed && completedCount > 0) {
      text = [
        '本次全球法布施已完成。',
        '',
        '素材：$title',
        '范围：$region',
        '完成：$completedCount 个国家',
        '数据量：${model.globalDataSentMB.toStringAsFixed(2)} MB',
        if (elapsed != null) '用时：$elapsed',
      ].join('\n');
    } else if (model.status == TransferStatus.error) {
      text = [
        '本次发送遇到问题。',
        if (model.currentLog.trim().isNotEmpty) model.currentLog.trim(),
      ].join('\n');
    } else if (model.isTransferring) {
      text = '本地模块仍在运行，可以点击右侧停止按钮结束。';
    } else {
      text = [
        '本次发送已停止。',
        if (completedCount > 0) '已完成：$completedCount 个国家',
        if (model.globalDataSentMB > 0)
          '数据量：${model.globalDataSentMB.toStringAsFixed(2)} MB',
      ].join('\n');
    }

    setState(() {
      _homeChatMessages.add(_HomeChatMessage(text: text, isUser: false));
      _isGlobalSendTimelineVisible = model.isTransferring;
      if (!model.isTransferring) {
        _currentSendingCountry = '';
        _sendStartedAt = null;
      }
    });
    _scrollHomeChatToBottom();
  }

  void _startSending(FileTransferModel model) async {
    if (model.isPreparingSend || model.isTransferring) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('后台正有一个会话在全球法布施，请等待完成或先停止后再开启新的全球法布施。'),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    final composerText = _chatInputController.text.trim();
    if (composerText.isNotEmpty) {
      try {
        final sharedLink = _firstHttpUrl(composerText);
        if (_looksLikeHttpUrl(composerText)) {
          await model.addUrlContentForSending(composerText);
        } else if (sharedLink != null) {
          await model.addUrlContentForSending(sharedLink);
        } else {
          await model.addTextContentForSending(
            title: '法布施',
            text: composerText,
            sourceKind: '文本',
            replaceExisting: !model.hasFiles,
          );
        }
        _chatInputController.clear();
        if (mounted) setState(() {});
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('内容准备失败: $e'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    if (!mounted) return;

    if (model.isLocalLoopbackEnabled) {
      final authModel = Provider.of<AuthModel?>(context, listen: false);
      final hasPremiumAccess = authModel?.hasPermission('premium') ?? false;
      if (!hasPremiumAccess) {
        model.setLocalLoopbackEnabled(false);
        _showLoopbackMembershipPrompt();
        return;
      }
    }

    if (model.hasFiles && _isBuddhaAssetSelected(model)) {
      final unlocked = await _ensureBuddhaAssetUnlocked();
      if (!unlocked) {
        model.clearFiles();
        return;
      }
    }

    if (!mounted) return;

    if (!model.hasFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入要法布施的文字或链接，或点 + 添加图片。'),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    final sendTitle = _sendContentTitle(model, composerText);
    final sendRegion = _regionSummary(model);

    setState(() {
      _homeChatMessages.add(
        _HomeChatMessage(text: '开始全球法布施：$sendTitle', isUser: true),
      );
      _isDharmaComposerMode = false;
      _showMaterialGallery = false;
      _isGlobalSendTimelineVisible = true;
      _activeSendTitle = sendTitle;
      _activeSendRegion = sendRegion;
      _sendStartedAt = DateTime.now();
      _isCallbackSetup = false;
    });
    _scrollHomeChatToBottom();

    if (_isNativeAndroid && mounted) {
      try {
        await AutoStartGuideDialog.showIfNeeded(context);
      } catch (e) {
        debugPrint('Auto-start guide failed, continuing send: $e');
      }
    }

    await _onlineCounterService.joinActivity('global_sending');
    _clearActiveSceneBeams();

    await model.startGlobalTransfer();

    if (!model.isTransferring) {
      await _onlineCounterService.leaveActivity();
      _clearActiveSceneBeams();
    }

    if (mounted) {
      setState(() {
        _currentSendingCountry = '';
      });
    }

    if (!mounted) return;
    _appendGlobalSendResult(model);
  }

  void _stopSending(FileTransferModel model) async {
    model.stopTransfer();
    await _onlineCounterService.leaveActivity();
    _clearActiveSceneBeams();

    setState(() {
      _currentSendingCountry = '';
      _isGlobalSendTimelineVisible = false;
    });

    if (mounted) _appendGlobalSendResult(model);
  }
}

class _ComposerChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _ComposerChip({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = active ? AppTheme.primaryColor : Colors.white70;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 230, minHeight: 34),
        padding: EdgeInsets.only(
          left: 10,
          right: onRemove == null ? 12 : 8,
          top: 6,
          bottom: 6,
        ),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primaryColor.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? AppTheme.primaryColor.withValues(alpha: 0.38)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Icon(Icons.close, color: foreground, size: 17),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RegionCheckTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _RegionCheckTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor.withValues(alpha: 0.38)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: selected ? AppTheme.primaryColor : Colors.white70,
                  size: 21,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: selected,
                onChanged: (value) => onChanged(value ?? false),
                activeColor: AppTheme.primaryColor,
                checkColor: Colors.black,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformCheckTile extends StatelessWidget {
  final DharmaPublishPlatform platform;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _PlatformCheckTile({
    required this.platform,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final info = platform.info;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor.withValues(alpha: 0.38)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.campaign_outlined,
                color: selected ? AppTheme.primaryColor : Colors.white70,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: selected,
                onChanged: (value) => onChanged(value ?? false),
                activeColor: AppTheme.primaryColor,
                checkColor: Colors.black,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareTargetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareTargetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _AiActivityLabel extends StatelessWidget {
  final String label;

  const _AiActivityLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor.withValues(alpha: 0.82),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownChatText extends StatelessWidget {
  final String data;
  final bool light;

  const _MarkdownChatText(this.data, {this.light = false});

  @override
  Widget build(BuildContext context) {
    final baseColor = light ? const Color(0xFF23272B) : Colors.white;
    final mutedColor = light ? const Color(0xFF5E666B) : Colors.white70;
    final codeColor = light ? const Color(0xFF123B59) : const Color(0xFFE9F4FF);
    final baseStyle = TextStyle(
      color: baseColor,
      fontSize: 17,
      height: 1.46,
      fontWeight: FontWeight.w500,
    );

    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      onTapLink: (text, href, title) async {
        final target = href?.trim();
        if (target == null || target.isEmpty) return;
        final uri = target.startsWith('/')
            ? Uri.file(target)
            : Uri.tryParse(target);
        if (uri == null) {
          await Clipboard.setData(ClipboardData(text: target));
          return;
        }
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!opened) {
          await Clipboard.setData(ClipboardData(text: target));
        }
      },
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: baseStyle,
        strong: baseStyle.copyWith(fontWeight: FontWeight.w800),
        em: baseStyle.copyWith(fontStyle: FontStyle.italic),
        h1: baseStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
        h2: baseStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
        h3: baseStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
        blockquote: baseStyle.copyWith(color: mutedColor),
        blockquoteDecoration: BoxDecoration(
          color: light
              ? const Color(0xFFF2F5F5)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: AppTheme.primaryColor.withValues(alpha: 0.72),
              width: 3,
            ),
          ),
        ),
        code: baseStyle.copyWith(
          color: codeColor,
          fontFamily: 'monospace',
          fontSize: 15,
        ),
        codeblockDecoration: BoxDecoration(
          color: light
              ? const Color(0xFFF3F5F6)
              : Colors.black.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: light
                ? const Color(0xFFE1E5E6)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        listBullet: baseStyle,
        a: baseStyle.copyWith(
          color: AppTheme.primaryColor,
          decoration: TextDecoration.underline,
          decorationColor: AppTheme.primaryColor.withValues(alpha: 0.7),
        ),
        tableBody: baseStyle.copyWith(fontSize: 14),
        tableHead: baseStyle.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: light
                  ? const Color(0xFFE1E5E6)
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
        ),
      ),
    );
  }
}

enum _HomeChatMessageType { text, contentPreview, choice, flashcardPreview }

class _HomeChatMessage {
  final String id;
  String text;
  final bool isUser;
  final bool isError;
  final _HomeChatMessageType messageType;
  final PreparedContent? content;
  final FlashcardDeck? deck;
  final List<_HomeChoiceOption> choices;
  String? selectedValue;

  _HomeChatMessage({
    String? id,
    required this.text,
    required this.isUser,
    this.isError = false,
    this.messageType = _HomeChatMessageType.text,
    this.content,
    this.deck,
    this.choices = const [],
  }) : selectedValue = null,
       id = id ?? flashcardId('home_msg');

  factory _HomeChatMessage.contentPreview({required PreparedContent content}) {
    return _HomeChatMessage(
      text: content.summary,
      isUser: false,
      isError: content.isFailed,
      messageType: _HomeChatMessageType.contentPreview,
      content: content,
    );
  }

  factory _HomeChatMessage.choice({
    required String text,
    required List<_HomeChoiceOption> choices,
  }) {
    return _HomeChatMessage(
      text: text,
      isUser: false,
      messageType: _HomeChatMessageType.choice,
      choices: choices,
    );
  }

  factory _HomeChatMessage.flashcardPreview({required FlashcardDeck deck}) {
    return _HomeChatMessage(
      text: deck.title,
      isUser: false,
      messageType: _HomeChatMessageType.flashcardPreview,
      deck: deck,
    );
  }
}

class _HomeChoiceOption {
  final String value;
  final IconData icon;
  final String title;
  final String subtitle;
  final FutureOr<void> Function()? onSelected;

  const _HomeChoiceOption({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onSelected,
  });
}

class _MiniInfoPill extends StatelessWidget {
  final String label;

  const _MiniInfoPill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InlineChoiceButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  const _InlineChoiceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.selected = false,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppTheme.primaryColor : Colors.white;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: disabled ? 0.48 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeConversation {
  final String? id;
  final String title;
  final List<_HomeChatMessage> messages;
  final DateTime updatedAt;
  final bool isGlobalSendRunning;

  const _HomeConversation({
    this.id,
    required this.title,
    required this.messages,
    required this.updatedAt,
    this.isGlobalSendRunning = false,
  });
}

class _DrawerSectionLabel extends StatelessWidget {
  final String label;
  final bool light;

  const _DrawerSectionLabel(this.label, {this.light = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          color: light ? const Color(0xFF9EA1A3) : Colors.white38,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String title;
  final bool selected;
  final bool running;
  final bool light;
  final VoidCallback? onTap;

  const _ConversationTile({
    required this.title,
    required this.selected,
    this.running = false,
    this.light = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = light ? const Color(0xFF202124) : Colors.white;
    final muted = light ? const Color(0xFF6E7377) : Colors.white70;
    final selectedColor = light
        ? const Color(0xFFDCDDDB)
        : Colors.white.withValues(alpha: 0.08);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            running
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : Icon(
                    selected ? Icons.chat_bubble : Icons.history,
                    color: muted,
                    size: 18,
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: foreground,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPromptPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool compact;
  final VoidCallback onTap;

  const _QuickPromptPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final height = compact ? 54.0 : 60.0;
    final horizontalPadding = compact ? 16.0 : 20.0;
    final iconSize = compact ? 22.0 : 24.0;
    final labelSize = compact ? 16.0 : 17.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          color: const Color(0xFF24262B).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: iconSize),
            SizedBox(width: compact ? 10 : 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: labelSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DesktopModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2F3033) : const Color(0xFFE7E7E5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : const Color(0xFF4E5356),
              size: 19,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF4E5356),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopPromptPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DesktopPromptPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E3E2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF4E5356), size: 19),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF303236),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopStatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DesktopStatusPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE4F7EF) : const Color(0xFFE9EAEA),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? const Color(0xFFB6E8D5) : const Color(0xFFDCDDDB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? const Color(0xFF00A37E) : const Color(0xFF6E7377),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? const Color(0xFF047B62)
                    : const Color(0xFF5F6368),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopPendingActionPill extends StatelessWidget {
  final String summary;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _DesktopPendingActionPill({
    required this.summary,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFD988)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.touch_app_outlined,
            color: Color(0xFF9A5A00),
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              summary,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF7A4700),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onReject,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                '拒绝',
                style: TextStyle(
                  color: Color(0xFF8A4B00),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: onApprove,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00A37E),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '允许',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool light;
  final bool accent;
  final VoidCallback onTap;

  const _MessageActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.light = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = accent
        ? AppTheme.primaryColor
        : light
        ? const Color(0xFF4E5356)
        : Colors.white70;
    final background = accent
        ? AppTheme.primaryColor.withValues(alpha: light ? 0.12 : 0.18)
        : light
        ? const Color(0xFFF1F3F3)
        : Colors.white.withValues(alpha: 0.08);

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: accent
                  ? AppTheme.primaryColor.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: light ? 0.0 : 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 15),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageFileRef {
  final String label;
  final String target;
  final bool isRemote;

  const _MessageFileRef({
    required this.label,
    required this.target,
    required this.isRemote,
  });
}

class _MessageFileChip extends StatelessWidget {
  final _MessageFileRef ref;
  final bool light;
  final VoidCallback onOpen;
  final VoidCallback onCopy;

  const _MessageFileChip({
    required this.ref,
    required this.onOpen,
    required this.onCopy,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = light ? const Color(0xFF303236) : Colors.white;
    final muted = light ? const Color(0xFF6E7377) : Colors.white60;

    return Container(
      constraints: const BoxConstraints(maxWidth: 310),
      height: 36,
      decoration: BoxDecoration(
        color: light
            ? const Color(0xFFF3F5F5)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: light
              ? const Color(0xFFE1E5E6)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ref.isRemote
                        ? Icons.cloud_download_outlined
                        : Icons.insert_drive_file_outlined,
                    color: foreground,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      ref.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 18, color: muted.withValues(alpha: 0.3)),
          Tooltip(
            message: '复制地址',
            child: InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Icon(Icons.copy_rounded, color: muted, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopComposerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _DesktopComposerButton({
    required this.icon,
    required this.label,
    // ignore: unused_element_parameter
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF34363A), size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF34363A),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Color(0xFF70757A),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final String priceLabel;
  final bool locked;
  final bool selected;
  final VoidCallback onTap;

  const _MaterialCard({
    required this.imagePath,
    required this.title,
    required this.priceLabel,
    required this.locked,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 1.42,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(imagePath, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x11000000), Color(0xCC000000)],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.greenAccent.withValues(alpha: 0.92)
                            : Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selected
                                ? Icons.check
                                : locked
                                ? Icons.lock
                                : Icons.lock_open,
                            color: selected ? Colors.black : Colors.white,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            selected ? '已选择' : priceLabel,
                            style: TextStyle(
                              color: selected ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
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

class _ThinkingDots extends StatefulWidget {
  final String label;

  const _ThinkingDots({required this.label});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots> {
  Timer? _timer;
  int _phase = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted) return;
      setState(() => _phase = (_phase + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 430),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white70, size: 17),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              '${widget.label}${List.filled(_phase, '.').join()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenSendScene extends StatefulWidget {
  final bool useThreeD;
  final FileTransferModel model;
  final VoidCallback onClose;

  const _FullScreenSendScene({
    required this.useThreeD,
    required this.model,
    required this.onClose,
  });

  @override
  State<_FullScreenSendScene> createState() => _FullScreenSendSceneState();
}

class _FullScreenSendSceneState extends State<_FullScreenSendScene> {
  final GlobalKey<HomeWorld2DWidgetState> _world2DKey = GlobalKey();
  final GlobalKey<EarthGlobeWidgetState> _globe3DKey = GlobalKey();
  final List<Map<String, dynamic>> _pendingBeams = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setupTransferBeamCallback();
    });
  }

  @override
  void dispose() {
    widget.onClose();
    super.dispose();
  }

  void _setupTransferBeamCallback() {
    widget.model.setTransferBeamCallback((
      fromLat,
      fromLng,
      toLat,
      toLng, {
      String? fromLabel,
      String? toLabel,
      Duration? displayDuration,
    }) {
      final added = _addTransferBeam(
        fromLat,
        fromLng,
        toLat,
        toLng,
        duration: displayDuration ?? const Duration(milliseconds: 900),
        toLabel: toLabel,
      );
      if (!added) {
        _pendingBeams.add({
          'fromLat': fromLat,
          'fromLng': fromLng,
          'toLat': toLat,
          'toLng': toLng,
          'toLabel': toLabel,
        });
        if (_pendingBeams.length > 20) _pendingBeams.removeAt(0);
      }
    });
    _playPendingBeams();
  }

  bool _addTransferBeam(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng, {
    Duration? duration,
    String? toLabel,
  }) {
    try {
      if (widget.useThreeD) {
        final state = _globe3DKey.currentState;
        if (state == null) return false;
        state.addTransferBeam(
          fromLat,
          fromLng,
          toLat,
          toLng,
          duration: duration,
          toLabel: toLabel,
        );
        return true;
      }

      final state = _world2DKey.currentState;
      if (state == null) return false;
      state.addTransferBeam(
        fromLat,
        fromLng,
        toLat,
        toLng,
        duration: duration,
        toLabel: toLabel,
      );
      return true;
    } catch (e) {
      debugPrint('全屏地球轨迹添加失败: $e');
      return false;
    }
  }

  void _playPendingBeams() {
    if (_pendingBeams.isEmpty) return;
    final hasScene = widget.useThreeD
        ? _globe3DKey.currentState != null
        : _world2DKey.currentState != null;
    if (!hasScene) {
      Future.delayed(const Duration(milliseconds: 300), _playPendingBeams);
      return;
    }

    for (final beam in _pendingBeams) {
      _addTransferBeam(
        beam['fromLat'] as double,
        beam['fromLng'] as double,
        beam['toLat'] as double,
        beam['toLng'] as double,
        duration: const Duration(seconds: 3),
        toLabel: beam['toLabel'] as String?,
      );
    }
    _pendingBeams.clear();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setupTransferBeamCallback();
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: widget.useThreeD
                  ? EarthGlobeWidget(key: _globe3DKey)
                  : HomeWorld2DWidget(key: _world2DKey),
            ),
            Positioned(
              top: 14,
              left: 14,
              child: IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.44),
                  fixedSize: const Size(46, 46),
                ),
              ),
            ),
            Positioned(
              left: 76,
              top: 22,
              right: 76,
              child: Text(
                widget.useThreeD ? '3D 实时轨迹' : '2D 实时轨迹',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendMenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SendMenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
