import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/config/app_config.dart';
import '../core/constants/country_servers.dart' as country_catalog;
import '../features/auth/application/auth_model.dart';
import '../models/file_transfer_model.dart';
import '../services/ai_backend_policy.dart';
import '../services/dacheng_ai_service.dart';
import '../widgets/earth_globe_widget.dart';
import '../widgets/home_world_2d_widget.dart';
import '../widgets/scene_render_mode.dart';
import 'leaderboard_screen.dart';
import '../core/design_system/app_theme.dart';
import '../services/alipay_service.dart';
import '../services/apple_iap_service.dart';
import '../services/membership_service.dart';
import '../services/online_counter_service.dart';
import '../widgets/auto_start_guide_dialog.dart';
import 'membership_screen.dart';

class GlobeHomeScreen extends StatefulWidget {
  const GlobeHomeScreen({super.key});

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
  bool _showMaterialGallery = false;
  bool _isGlobalSendTimelineVisible = false;
  bool _isAiGenerating = false;
  String _streamingAiText = '';
  String _aiActivityText = '';
  SceneRenderMode _renderMode = SceneRenderMode.twoD;
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _homeChatScrollController = ScrollController();
  final List<_HomeChatMessage> _homeChatMessages = [];
  final List<_HomeConversation> _conversationHistory = [];
  StreamSubscription<DachengAiStreamEvent>? _aiStreamSubscription;
  final DachengAiService _dachengAiService = DachengAiService();
  String? _activeConversationId;
  int _aiRequestSerial = 0;
  final _onlineCounterService = OnlineCounterService();
  final _membershipService = MembershipService();
  final _alipayService = AlipayService();
  final _appleIapService = AppleIapService();
  bool? _buddhaAssetUnlocked;
  bool _isPurchasingBuddhaAsset = false;
  DateTime? _sendStartedAt;
  String _activeSendTitle = '';
  String _activeSendRegion = '';

  void setVisible(bool visible) {
    if (_isVisible == visible) return;
    _isVisible = visible;
    debugPrint('🌍 地球页面可见性变化: $visible');

    _syncActiveSceneVisibility();
    if (visible) {
      _playPendingBeams();
    }
  }

  bool get _canUseThreeDNow {
    final authModel = Provider.of<AuthModel?>(context, listen: false);
    return SceneRenderAccess.canUseThreeDFor(authModel);
  }

  bool get _isThreeDActiveNow {
    return _renderMode == SceneRenderMode.threeD && _canUseThreeDNow;
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
    if (_renderMode == SceneRenderMode.twoD && !_canUseThreeDNow) {
      showThreeDMemberPrompt(context);
      return;
    }

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
    WidgetsBinding.instance.addObserver(this);
    _loadGlobe();
    _fetchInitialCount();
    _onlineCounterService.startCountPolling('global_sending');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadRemoteConversations());
      unawaited(_refreshBuddhaAssetEntitlement());
    });
  }

  Future<void> _fetchInitialCount() async {
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      await _onlineCounterService.fetchCountForActivity('global_sending');
    } catch (e) {
      debugPrint('获取初始在线人数失败: $e');
    }
  }

  Future<void> _loadRemoteConversations() async {
    try {
      final authModel = Provider.of<AuthModel?>(context, listen: false);
      final summaries = await _dachengAiService.listConversations(
        token: authModel?.authToken,
        username: authModel?.currentUser?.username,
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
    _aiStreamSubscription?.cancel();
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
                return Column(
                  children: [
                    _buildTopBar(authModel),
                    Expanded(child: _buildHomeBody(context, model, authModel)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                      child: _buildChatComposer(context, model),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
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
        height: 52,
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
              child: Row(
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
    return FutureBuilder<String>(
      future: AiBackendPolicy.activeBackendLabel(),
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
    final currentTitle = _conversationTitleFrom(_homeChatMessages);

    return Drawer(
      width: drawerWidth,
      backgroundColor: const Color(0xFF1E2024),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Consumer<FileTransferModel>(
            builder: (context, model, _) {
              final isBusy = _isAiGenerating;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '大乘',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isBusy
                          ? null
                          : () => _startNewConversation(model),
                      icon: const Icon(Icons.add_comment_outlined, size: 20),
                      label: const Text('开启新对话'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF30343A),
                        disabledBackgroundColor: Colors.white.withValues(
                          alpha: 0.08,
                        ),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _DrawerSectionLabel('今天'),
                  if (_homeChatMessages.isNotEmpty) ...[
                    _ConversationTile(
                      title: currentTitle,
                      selected: true,
                      running: _shouldShowGlobalSendProcess(model),
                      onTap: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: _conversationHistory.isEmpty
                        ? const Center(
                            child: Text(
                              '没有更多内容啦',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _conversationHistory.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final conversation = _conversationHistory[index];
                              return _ConversationTile(
                                title: conversation.title,
                                selected: false,
                                running: conversation.isGlobalSendRunning,
                                onTap: isBusy
                                    ? null
                                    : () => _openConversation(conversation),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
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

  Widget _buildChatTimeline(FileTransferModel model) {
    final hasSendingProcess = _shouldShowGlobalSendProcess(model);

    return ListView(
      key: const ValueKey('chat'),
      controller: _homeChatScrollController,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      children: [
        for (final message in _homeChatMessages) ...[
          _buildChatBubble(message),
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
                    ),
                  ],
                ),
        if (_isAiGenerating) const SizedBox(height: 18),
        if (hasSendingProcess) _buildGlobalSendingProcess(model),
      ],
    );
  }

  Widget _buildChatBubble(_HomeChatMessage message) {
    final bubbleColor = message.isUser
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
        constraints: const BoxConstraints(maxWidth: 430),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(color: bubbleColor, borderRadius: radius),
        child: message.isUser || message.isError
            ? Text(
                message.text,
                style: TextStyle(
                  color: message.isError ? Colors.red[100] : Colors.white,
                  fontSize: 17,
                  height: 1.42,
                  fontWeight: message.isUser
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              )
            : _MarkdownChatText(message.text),
      ),
    );
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
    setState(() {});
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
        (_isDharmaComposerMode && model.isTransferring);
    final inputText = _chatInputController.text.trim();
    final canSubmit = _isDharmaComposerMode
        ? (inputText.isNotEmpty || model.hasFiles)
        : inputText.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 7, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF242424).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(_isDharmaComposerMode ? 24 : 26),
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
          if (_isDharmaComposerMode) ...[
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
                        ? (model.hasFiles ? '可继续输入法布施文字或链接' : '输入文字或链接')
                        : '问问 AI',
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

  Widget _buildComposerActionButton(
    FileTransferModel model, {
    required bool canSubmit,
  }) {
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
      tooltip: _isDharmaComposerMode ? '开始法布施' : '发送消息',
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
          _isDharmaComposerMode ? '已选择，可在输入框上方调整' : '默认全球发送',
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
      _activateDharmaMode(model, showMaterials: true);
      return true;
    }
    if (action == 'files') {
      _activateDharmaMode(model);
      final selected = await model.selectFiles(replaceExisting: true);
      if (selected && mounted) setState(() {});
      return selected;
    }
    return false;
  }

  void _submitComposer(FileTransferModel model) {
    if (_isDharmaComposerMode) {
      _startSending(model);
    } else {
      _sendAiChatFromComposer();
    }
  }

  void _activateDharmaMode(
    FileTransferModel model, {
    bool showMaterials = false,
  }) {
    if (model.countryList.isEmpty) {
      model.setCountryList(['ALL']);
    }
    if (!model.isGlobalSendEnabled &&
        !model.isFieldEnergyMode &&
        !model.isLocalLoopbackEnabled) {
      model.setGlobalSendEnabled(true);
      model.setCountryList(['ALL']);
    }
    setState(() {
      _isDharmaComposerMode = true;
      _showMaterialGallery = showMaterials;
    });
  }

  void _clearDharmaMode(FileTransferModel model) {
    _chatInputController.clear();
    model.clearFiles();
    setState(() {
      _isDharmaComposerMode = false;
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

  Future<void> _sendAiChatFromComposer() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty || _isAiGenerating) return;

    HapticFeedback.lightImpact();
    final requestSerial = ++_aiRequestSerial;
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
    _scrollHomeChatToBottom(force: true);

    try {
      final stepLines = <String>[];
      var finalText = '';
      String? latestConversationId = _activeConversationId;

      await for (final event in _dachengAiService.sendChatStream(
        message: text,
        conversationId: _activeConversationId,
        token: authModel?.authToken,
        username: authModel?.currentUser?.username,
        isMember: authModel?.hasPermission('premium') ?? false,
      )) {
        if (!mounted || requestSerial != _aiRequestSerial) return;

        if (event.conversationId != null && event.conversationId!.isNotEmpty) {
          latestConversationId = event.conversationId;
        }

        if (event.isStep) {
          final visibleStep = _visibleAiStepLabel(event);
          if (visibleStep != null) {
            stepLines
              ..clear()
              ..add(visibleStep);
          }
        } else if (event.isDelta) {
          finalText += event.text;
        } else if (event.isDone) {
          latestConversationId = event.conversationId ?? latestConversationId;
          finalText = (event.raw['message'] ?? finalText).toString();
        } else if (event.isError) {
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
    } catch (e) {
      if (!mounted || requestSerial != _aiRequestSerial) return;
      setState(() {
        _homeChatMessages.add(
          _HomeChatMessage(
            text: '大乘 AI 生成失败: $e',
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

  void _stopAiGeneration() {
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
    } else if (Platform.isIOS) {
      title = '开启个人热点';
      steps = [
        '1. 点击下方"前往设置"按钮',
        '2. 找到"个人热点"选项',
        '3. 开启"允许其他人加入"',
        '4. 返回本应用开始发送',
      ];
      tip = '💡 开启热点后，经文能量将通过 Wi-Fi 信号向周围空间广播';
    } else if (Platform.isAndroid) {
      title = '开启便携式热点';
      steps = [
        '1. 点击下方"前往设置"按钮',
        '2. 找到"热点与网络共享"或"便携式热点"',
        '3. 开启"便携式 WLAN 热点"',
        '4. 返回本应用开始发送',
      ];
      tip = '💡 开启热点后，经文能量将通过 Wi-Fi 信号向周围空间广播';
    } else if (Platform.isMacOS) {
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
    if (kIsWeb || !Platform.isAndroid) {
      _showBuddhaAssetMessage('请在 Android 手机端使用支付宝解锁', color: Colors.orange);
      return false;
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
        if (_looksLikeHttpUrl(composerText)) {
          await model.addUrlContentForSending(composerText);
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

    if (!kIsWeb && Platform.isAndroid && mounted) {
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

  const _MarkdownChatText(this.data);

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      color: Colors.white,
      fontSize: 17,
      height: 1.46,
      fontWeight: FontWeight.w500,
    );

    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: baseStyle,
        strong: baseStyle.copyWith(fontWeight: FontWeight.w800),
        em: baseStyle.copyWith(fontStyle: FontStyle.italic),
        h1: baseStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
        h2: baseStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
        h3: baseStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
        blockquote: baseStyle.copyWith(color: Colors.white70),
        blockquoteDecoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: AppTheme.primaryColor.withValues(alpha: 0.72),
              width: 3,
            ),
          ),
        ),
        code: baseStyle.copyWith(
          color: const Color(0xFFE9F4FF),
          fontFamily: 'monospace',
          fontSize: 15,
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
            top: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
        ),
      ),
    );
  }
}

class _HomeChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  const _HomeChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
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

  const _DrawerSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
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
  final VoidCallback? onTap;

  const _ConversationTile({
    required this.title,
    required this.selected,
    this.running = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
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
                    color: Colors.white70,
                    size: 18,
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
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
