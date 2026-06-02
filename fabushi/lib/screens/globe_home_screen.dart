import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/config/app_config.dart';
import '../core/constants/country_servers.dart' as country_catalog;
import '../features/auth/application/auth_model.dart';
import '../models/file_transfer_model.dart';
import '../services/app_settings.dart';
import '../widgets/earth_globe_widget.dart';
import '../widgets/home_world_2d_widget.dart';
import '../widgets/scene_render_mode.dart';
import 'leaderboard_screen.dart';
import '../core/design_system/app_theme.dart';
import '../services/alipay_service.dart';
import '../services/apple_iap_service.dart';
import '../services/llm_inference_service.dart';
import '../services/llm_model_config.dart';
import '../services/llm_model_manager.dart';
import '../services/membership_service.dart';
import '../services/online_counter_service.dart';
import '../widgets/online_counter_widget.dart';
import '../widgets/auto_start_guide_dialog.dart';
import 'membership_screen.dart';

class GlobeHomeScreen extends StatefulWidget {
  const GlobeHomeScreen({super.key});

  @override
  State<GlobeHomeScreen> createState() => GlobeHomeScreenState();
}

class GlobeHomeScreenState extends State<GlobeHomeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final GlobalKey<HomeWorld2DWidgetState> _world2DKey = GlobalKey();
  final GlobalKey<EarthGlobeWidgetState> _globe3DKey = GlobalKey();
  String _currentSendingCountry = '';
  final List<Map<String, dynamic>> _pendingBeams = [];
  bool _isGlobeLoaded = false;
  bool _isCallbackSetup = false;
  bool _isVisible = true;
  bool _isDharmaComposerMode = false;
  bool _isAiGenerating = false;
  String _streamingAiText = '';
  SceneRenderMode _renderMode = SceneRenderMode.twoD;
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _homeChatScrollController = ScrollController();
  final List<_HomeChatMessage> _homeChatMessages = [];
  StreamSubscription<String>? _aiStreamSubscription;
  List<LLMModelType> _availableChatModels = [];
  LLMModelType? _selectedChatModel;
  final _onlineCounterService = OnlineCounterService();
  final _membershipService = MembershipService();
  final _alipayService = AlipayService();
  final _appleIapService = AppleIapService();
  bool? _buddhaAssetUnlocked;
  bool _isPurchasingBuddhaAsset = false;

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

  void _selectRenderMode(SceneRenderMode mode) {
    if (mode == SceneRenderMode.threeD && !_canUseThreeDNow) {
      if (_renderMode != SceneRenderMode.twoD) {
        setState(() => _renderMode = SceneRenderMode.twoD);
      }
      showThreeDMemberPrompt(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncActiveSceneVisibility();
      });
      return;
    }

    if (_renderMode == mode) return;
    setState(() => _renderMode = mode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncActiveSceneVisibility();
      _playPendingBeams();
    });
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGlobe();
    _loadAvailableChatModel();
    _fetchInitialCount();
    _onlineCounterService.startCountPolling('global_sending');
  }

  Future<void> _loadAvailableChatModel() async {
    if (kIsWeb) return;
    try {
      final downloadedModels = await LLMModelManager.instance
          .getDownloadedModels();
      final isMobile = Platform.isAndroid || Platform.isIOS;
      final platformModels = LLMModelConfig.getChatModelsForPlatform(
        isMobile: isMobile,
      );
      final supportedTypes = platformModels
          .map((config) => config.type)
          .toSet();
      final chatModels = downloadedModels
          .where((type) => supportedTypes.contains(type))
          .toList();

      LLMModelType? savedModel;
      final savedModelName = await AppSettings.getSelectedModelName();
      if (savedModelName != null) {
        try {
          savedModel = LLMModelType.values.firstWhere(
            (type) => type.name == savedModelName,
          );
          if (!chatModels.contains(savedModel)) savedModel = null;
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _availableChatModels = chatModels;
        _selectedChatModel =
            savedModel ?? (chatModels.isNotEmpty ? chatModels.first : null);
      });
    } catch (e) {
      debugPrint('首页 AI 模型加载失败: $e');
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
    final canUseThreeD = SceneRenderAccess.canUseThreeDFor(authModel);
    final effectiveMode = canUseThreeD ? _renderMode : SceneRenderMode.twoD;
    final useThreeD = effectiveMode == SceneRenderMode.threeD;

    if (!_isCallbackSetup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupTransferBeamCallback();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncActiveSceneVisibility();
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            color: Colors.transparent,
            child: _isGlobeLoaded
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      try {
                        return useThreeD
                            ? EarthGlobeWidget(key: _globe3DKey)
                            : HomeWorld2DWidget(key: _world2DKey);
                      } catch (e) {
                        debugPrint('⚠️ 首页场景渲染失败: $e');
                        return Container(
                          color: Colors.transparent,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.public,
                                  size: 80,
                                  color: Colors.cyan,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  '🌍 首页场景加载中...',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '请稍后或重启应用',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                  )
                : Container(
                    color: Colors.transparent,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.cyan),
                          SizedBox(height: 16),
                          Text(
                            '🌍 正在加载首页场景...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '首次加载可能需要几秒钟',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: OnlineCounterWidget(
              countStream: _onlineCounterService.onlineCountStream,
              initialCount: _onlineCounterService.currentCount,
              icon: Icons.public,
              prefix: '🌍 正在全球发送:',
              color: AppTheme.primaryColor,
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LeaderboardScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.leaderboard, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.glassDecoration.color,
                highlightColor: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
              tooltip: '排行榜',
            ),
          ),
          Consumer<FileTransferModel>(
            builder: (context, model, _) {
              if (!model.isTransferring || _currentSendingCountry.isEmpty) {
                return const SizedBox.shrink();
              }
              final scripture = model.currentSendingScripture;
              final materialCompleted = model.isCurrentMaterialCompleted;
              final countryProgress = model.currentCountryProgress;
              return Positioned(
                top: 70,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: AppTheme.glassDecoration.copyWith(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scripture.isEmpty
                                    ? '正在发送内容'
                                    : materialCompleted
                                    ? '已完成《$scripture》'
                                    : '正在发送《$scripture》',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '发送到 $_currentSendingCountry',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        materialCompleted
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.greenAccent,
                                size: 18,
                              )
                            : SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  value:
                                      countryProgress != null &&
                                          countryProgress > 0 &&
                                          countryProgress < 1
                                      ? countryProgress
                                      : null,
                                  strokeWidth: 2,
                                  color: Colors.cyan,
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: _buildControlPanel(context),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context) {
    return Consumer<FileTransferModel>(
      builder: (context, model, _) {
        return Container(
          decoration: AppTheme.glassDecoration,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (model.isPreparingSend) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            model.preparingSendMessage.isEmpty
                                ? '正在准备发送...'
                                : model.preparingSendMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (model.isTransferring) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.menu_book,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                model.currentSendingScripture.isEmpty
                                    ? '正在发送内容'
                                    : '正在发送：《${model.currentSendingScripture}》',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (model.loopbackCount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.cyanAccent,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '动态杨升高速转轮中',
                                style: TextStyle(
                                  color: Colors.cyanAccent.withValues(
                                    alpha: 0.9,
                                  ),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.cyanAccent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.cyanAccent.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (model.isFieldEnergyMode &&
                            model.fieldBroadcastCount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.wifi_tethering,
                                color: Colors.purple,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '场能广播: ${model.fieldBroadcastCount} 次',
                                style: const TextStyle(
                                  color: Colors.purple,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.purple,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.purple.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryColor,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  const Text(
                    '全球普渡',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  _buildRenderModeSegment(),
                  const SizedBox(height: 12),
                  if (!_isDharmaComposerMode &&
                      _homeChatMessages.isNotEmpty) ...[
                    _buildHomeChatThread(),
                    const SizedBox(height: 12),
                  ],
                ],
                _buildChatComposer(context, model),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRenderModeSegment() {
    final canUseThreeD = _canUseThreeDNow;
    final effectiveMode = canUseThreeD ? _renderMode : SceneRenderMode.twoD;

    return Align(
      alignment: Alignment.center,
      child: Container(
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.26),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24, width: 0.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRenderModeChoice(
              mode: SceneRenderMode.twoD,
              effectiveMode: effectiveMode,
              locked: false,
            ),
            _buildRenderModeChoice(
              mode: SceneRenderMode.threeD,
              effectiveMode: effectiveMode,
              locked: !canUseThreeD,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRenderModeChoice({
    required SceneRenderMode mode,
    required SceneRenderMode effectiveMode,
    required bool locked,
  }) {
    final selected = mode == effectiveMode;
    return Tooltip(
      message: locked ? '会员专享' : '${mode.shortLabel} 模式',
      child: GestureDetector(
        onTap: () => _selectRenderMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.92)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (locked) ...[
                const Icon(Icons.lock, color: Colors.white70, size: 13),
                const SizedBox(width: 4),
              ],
              Text(
                mode.shortLabel,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white70,
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

  Widget _buildHomeChatThread() {
    final messages = [
      ..._homeChatMessages,
      if (_isAiGenerating && _streamingAiText.isNotEmpty)
        _HomeChatMessage(text: _streamingAiText, isUser: false),
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: ListView.separated(
          controller: _homeChatScrollController,
          padding: const EdgeInsets.all(12),
          shrinkWrap: true,
          itemCount: messages.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final message = messages[index];
            final alignment = message.isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start;
            final bubbleColor = message.isUser
                ? AppTheme.primaryColor.withValues(alpha: 0.22)
                : message.isError
                ? Colors.red.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.08);

            return Column(
              crossAxisAlignment: alignment,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isError ? Colors.red[100] : Colors.white,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildChatComposer(BuildContext context, FileTransferModel model) {
    final isBusy = model.isPreparingSend || model.isTransferring;
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
                  enabled: !model.isPreparingSend && !model.isTransferring,
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

    if (model.isTransferring) {
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
      _activateDharmaMode(model);
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

  void _activateDharmaMode(FileTransferModel model) {
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
    });
  }

  void _clearDharmaMode(FileTransferModel model) {
    _chatInputController.clear();
    model.clearFiles();
    setState(() {
      _isDharmaComposerMode = false;
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
                                ? '本地回环独立运行'
                                : '会员可开启本地回环',
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
    await _aiStreamSubscription?.cancel();
    _aiStreamSubscription = null;
    _chatInputController.clear();
    setState(() {
      _homeChatMessages.add(_HomeChatMessage(text: text, isUser: true));
      _isAiGenerating = true;
      _streamingAiText = '';
    });
    _scrollHomeChatToBottom();

    try {
      if (kIsWeb) {
        throw UnsupportedError('Web 平台暂不支持本地 AI 对话');
      }
      final selectedModel = _selectedChatModel;
      if (selectedModel == null ||
          !_availableChatModels.contains(selectedModel)) {
        throw StateError('请先在 AI 页面下载并选择一个本地模型');
      }

      final inferenceService = LLMInferenceService.instance;
      final modelPath = await LLMModelManager.instance.getModelPath(
        selectedModel,
      );
      if (!inferenceService.isInitialized ||
          inferenceService.modelPath != modelPath) {
        await inferenceService.initialize(modelPath);
      }

      final stream = inferenceService.generateStream(_buildHomeAiPrompt(text));
      _aiStreamSubscription = stream.listen(
        (token) {
          if (!mounted) return;
          setState(() {
            _streamingAiText += token;
          });
          _scrollHomeChatToBottom();
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            if (_streamingAiText.trim().isNotEmpty) {
              _homeChatMessages.add(
                _HomeChatMessage(text: _streamingAiText, isUser: false),
              );
            }
            _streamingAiText = '';
            _isAiGenerating = false;
          });
          _scrollHomeChatToBottom();
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _homeChatMessages.add(
              _HomeChatMessage(
                text: '生成失败: $error',
                isUser: false,
                isError: true,
              ),
            );
            _streamingAiText = '';
            _isAiGenerating = false;
          });
          _scrollHomeChatToBottom();
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _homeChatMessages.add(
          _HomeChatMessage(text: '生成失败: $e', isUser: false, isError: true),
        );
        _streamingAiText = '';
        _isAiGenerating = false;
      });
      _scrollHomeChatToBottom();
    }
  }

  String _buildHomeAiPrompt(String question) {
    final previousMessages = _homeChatMessages.length > 1
        ? _homeChatMessages.take(_homeChatMessages.length - 1)
        : const Iterable<_HomeChatMessage>.empty();
    final recent = previousMessages
        .toList()
        .reversed
        .take(6)
        .toList()
        .reversed
        .map((message) => '${message.isUser ? "用户" : "AI"}: ${message.text}')
        .join('\n');

    return [
      '你是法布施应用首页里的 AI 助手。回答要简洁、直接、友善。',
      if (recent.isNotEmpty) '最近对话:\n$recent',
      '用户: $question',
      'AI:',
    ].join('\n\n');
  }

  void _stopAiGeneration() {
    _aiStreamSubscription?.cancel();
    _aiStreamSubscription = null;
    unawaited(LLMInferenceService.instance.stopGeneration());
    if (!mounted) return;
    setState(() {
      if (_streamingAiText.trim().isNotEmpty) {
        _homeChatMessages.add(
          _HomeChatMessage(text: _streamingAiText, isUser: false),
        );
      }
      _streamingAiText = '';
      _isAiGenerating = false;
    });
  }

  void _scrollHomeChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_homeChatScrollController.hasClients) return;
      _homeChatScrollController.animateTo(
        _homeChatScrollController.position.maxScrollExtent,
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
        content: const Text('本地回环是会员功能，开通会员后即可开启。'),
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
    return switch (kind) {
      '链接' => Icons.link,
      '文本' => Icons.edit_note,
      '本机文件' => Icons.folder_open,
      '素材文件' => Icons.inventory_2,
      '禅室佛像素材' => Icons.self_improvement,
      _ => Icons.library_books,
    };
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
      _showBuddhaAssetMessage('请先登录后再解锁禅室佛像素材', color: Colors.orange);
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
        content: const Text('付费后可在首页选择禅室内佛像模型素材，并加入全球发送内容。'),
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
          _showBuddhaAssetMessage('禅室佛像素材已解锁', color: Colors.green);
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
          _showBuddhaAssetMessage('禅室佛像素材已解锁', color: Colors.green);
          return true;
        }
      }
    }

    _showBuddhaAssetMessage('支付状态确认超时，请稍后重新进入首页检查', color: Colors.orange);
    return false;
  }

  bool _isBuddhaAssetSelected(FileTransferModel model) {
    return model.selectedContentKind == AppConfig.zenBuddhaAssetDisplayName ||
        model.currentSendingScripture == AppConfig.zenBuddhaAssetDisplayName;
  }

  bool _looksLikeHttpUrl(String text) {
    final uri = Uri.tryParse(text.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  void _startSending(FileTransferModel model) async {
    if (model.isPreparingSend || model.isTransferring) return;

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

    if (Platform.isAndroid && mounted) {
      try {
        await AutoStartGuideDialog.showIfNeeded(context);
      } catch (e) {
        debugPrint('Auto-start guide failed, continuing send: $e');
      }
    }

    await _onlineCounterService.joinActivity('global_sending');
    _clearActiveSceneBeams();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🌍 开始法布施到${_regionSummary(model)}...'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.black87,
        ),
      );
    }

    await model.startGlobalTransfer();
    final sentCount = model.globalSentCount;

    await _onlineCounterService.leaveActivity();
    _clearActiveSceneBeams();

    if (mounted) {
      setState(() {
        _currentSendingCountry = '';
      });
    }

    if (!mounted) return;
    if (model.status == TransferStatus.completed && sentCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ 所选内容已发送完成，共完成 $sentCount 个国家！'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (model.status == TransferStatus.idle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛑 已停止发送'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } else if (model.isTransferring) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('本地模块运行中，可点击停止结束。'),
          backgroundColor: Colors.black87,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _stopSending(FileTransferModel model) async {
    model.stopTransfer();
    await _onlineCounterService.leaveActivity();
    _clearActiveSceneBeams();

    setState(() {
      _currentSendingCountry = '';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛑 已停止发送'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
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
