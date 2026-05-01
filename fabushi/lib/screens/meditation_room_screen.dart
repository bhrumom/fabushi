import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import '../models/auth_model.dart';
import '../models/sutra_model.dart';
import '../services/practice_stats_service.dart';
import '../services/meditation_session_manager.dart';
import '../services/achievement_system.dart';
import 'buddha_model_screen.dart';
import 'sutra_reader_screen.dart';
import '../services/online_counter_service.dart';
import '../widgets/achievement_popup.dart';
import '../widgets/online_counter_widget.dart';
import '../widgets/practice_selection_sheet.dart';
import '../widgets/practice_leaderboard_sheet.dart';
import '../widgets/reflection_dialog.dart';

/// 禅室修行界面 - 零摩擦版本
///
/// 设计原则：
/// - 进入即开始：无需点击任何按钮
/// - 智能默认：自动使用上次功课
/// - 灵活时长：随时可停，无最低要求
/// - 即时反馈：成就系统实时激励
class MeditationRoomScreen extends StatefulWidget {
  const MeditationRoomScreen({Key? key}) : super(key: key);

  @override
  State<MeditationRoomScreen> createState() => MeditationRoomScreenState();
}

class MeditationRoomScreenState extends State<MeditationRoomScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// 公开方法：设置页面可见性（由主导航调用）
  void setVisible(bool visible) {
    _onVisibilityChanged(visible);
  }

  // ========== 核心服务 ==========
  final _sessionManager = MeditationSessionManager();
  final _achievementSystem = AchievementSystem();
  final _onlineCounterService = OnlineCounterService();

  // ========== 状态变量 ==========
  bool _isCircumambulating = false;
  bool _isInitialized = false;
  bool _isPageVisible = false; // 追踪页面是否可见

  // ========== 动画控制器 ==========
  late AnimationController _incenseController;
  late AnimationController _pulseController;
  late AnimationController _welcomeController;

  // ========== Key ==========
  final GlobalKey<BuddhaModelScreenState> _buddhaKey = GlobalKey();

  // ========== 成就监听 ==========
  StreamSubscription<Achievement>? _achievementSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _incenseController = AnimationController(
      vsync: this,
      duration: const Duration(hours: 2), // 极长时间，不再限制
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _welcomeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _incenseController.addListener(_onIncenseProgressChanged);

    // 初始化
    _initialize();
  }

  Future<void> _initialize() async {
    // 加载偏好和成就数据
    await Future.wait([
      _sessionManager.loadPreferences(),
      _achievementSystem.loadData(),
    ]);

    // 初始化音量监听（用于念诵计数）
    _initVolumeListener();

    // 获取在线人数
    _fetchInitialCount();

    // 监听成就事件
    _achievementSubscription = _achievementSystem.achievementStream.listen((
      achievement,
    ) {
      if (mounted) {
        AchievementPopup.show(context, achievement);
      }
    });

    setState(() => _isInitialized = true);

    // 启动时不主动弹出功课输入，等用户点击开始修行或功课按钮再提示。
  }

  /// 打开经文阅读界面
  void _openSutraReader() {
    final practice = _sessionManager.lockedPractice;
    if (practice != null && !practice.filePath.startsWith('manual:')) {
      openSutraReader(
        context,
        title: practice.title,
        filePath: practice.filePath,
      );
    }
  }

  /// 当页面可见性变化时调用
  void _onVisibilityChanged(bool visible) {
    if (_isPageVisible == visible) return;

    _isPageVisible = visible;
    debugPrint('🧘 禅室页面可见性变化: $visible');
    _syncAnimationVisibility();

    // 不再自动开始修行，需要用户手动点击"开始修行"按钮
    if (!visible && _sessionManager.isInSession) {
      // 离开禅室页面时暂停计时（但不结束）
      _sessionManager.pauseSession();
    } else if (visible && _sessionManager.isInSession) {
      // 重新进入禅室页面时恢复计时
      _sessionManager.resumeSession();
    }
  }

  void _syncAnimationVisibility() {
    if (_isPageVisible) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      if (_welcomeController.status == AnimationStatus.dismissed) {
        _welcomeController.forward();
      }
      if (_sessionManager.isInSession && !_incenseController.isAnimating) {
        _incenseController.forward();
      }
      return;
    }

    _pulseController.stop();
    _welcomeController.stop();
    _incenseController.stop();
  }

  /// 自动开始修行（零摩擦入口的核心）
  Future<void> _autoStartMeditation() async {
    // 防止重复开始
    if (_sessionManager.isInSession) {
      debugPrint('🧘 已经开始修行，跳过');
      return;
    }

    if (!_ensureCloudRecordingReady()) return;

    // 检查是否已选择功课
    if (!_sessionManager.isPracticeLocked) {
      // 未选择功课，弹出选择界面并提醒
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先选择一门深入的修行功课'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        showPracticeSelectionSheet(
          context,
          onSelected: () {
            // 功课选择完成后刷新界面
            if (mounted) setState(() {});
          },
        );
      }
      return;
    }

    // 确保页面可见
    if (!_isPageVisible) {
      debugPrint('🧘 页面不可见，跳过自动开始');
      return;
    }

    // 稍等一下让UI完成渲染
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted || !_isPageVisible) return;

    // 使用锁定的功课开始
    await _sessionManager.instantStart(
      sutra: _sessionManager.lockedPractice?.title,
    );

    // 触发开始成就
    await _achievementSystem.onSessionStart();

    // 开始香的燃烧动画
    if (_isPageVisible) {
      _incenseController.reset();
      _incenseController.forward();
    }

    // 加入在线活动
    _onlineCounterService.joinActivity('zen_room');

    if (mounted) setState(() {});
  }

  bool _ensureCloudRecordingReady() {
    final authModel = context.read<AuthModel>();
    if (authModel.isLoggedIn && authModel.authToken != null) {
      PracticeStatsService().setAuthToken(authModel.authToken);
      return true;
    }

    if (!mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('请先登录，修行记录将保存到云端'),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: '去登录',
          textColor: Colors.white,
          onPressed: () => Navigator.pushNamed(context, '/login'),
        ),
      ),
    );
    return false;
  }

  void _onIncenseProgressChanged() {
    _buddhaKey.currentState?.updateIncenseProgress(_incenseController.value);
  }

  Future<void> _fetchInitialCount() async {
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      await _onlineCounterService.fetchCountForActivity('zen_room');
    } catch (e) {
      debugPrint('获取初始在线人数失败: $e');
    }
  }

  Future<void> _initVolumeListener() async {
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
      FlutterVolumeController.addListener((volume) {
        if (_sessionManager.isInSession) {
          _sessionManager.incrementChant();
        }
      });
    } catch (e) {
      debugPrint('音量监听初始化失败: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // 应用进入后台，暂停计时但保留状态
      _sessionManager.pauseSession();
    } else if (state == AppLifecycleState.resumed) {
      // 应用恢复，继续计时
      if (_sessionManager.isInSession) {
        _sessionManager.resumeSession();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _achievementSubscription?.cancel();
    _incenseController.removeListener(_onIncenseProgressChanged);
    _incenseController.dispose();
    _pulseController.dispose();
    _welcomeController.dispose();
    FlutterVolumeController.removeListener();
    _onlineCounterService.dispose();
    super.dispose();
  }

  /// 结束修行并同步数据
  Future<void> _endMeditation() async {
    final result = await _sessionManager.endSession();
    _incenseController.stop();
    _incenseController.reset();
    _buddhaKey.currentState?.updateIncenseProgress(0);

    if (result.success) {
      // 触发结束成就
      await _achievementSystem.onSessionEnd(
        duration: result.duration,
        chantCount: result.chantCount,
        sutra: result.sutra ?? '默认功课',
      );

      // 离开在线活动
      await _onlineCounterService.leaveActivity();

      String? reflectionNotes;
      final practice = _sessionManager.lockedPractice;
      if (mounted && practice != null) {
        reflectionNotes = await showReflectionDialog(
          context,
          duration: result.duration,
          chantCount: result.chantCount,
          sutraTitle: practice.title,
          filePath: practice.filePath,
        );
      }
      if (!mounted) return;

      // 修行记录必须进入云端保存链路。网络异常时服务会放入待同步队列。
      final savedToCloud = await _syncToCloud(result, notes: reflectionNotes);

      if (mounted && !savedToCloud) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('云端保存失败，请登录并检查网络后重试'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else if (mounted && PracticeStatsService().lastWriteQueued) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('网络暂不可用，记录已加入云端待同步'),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (mounted && reflectionNotes?.isNotEmpty == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('心得已保存到修行记录，仅自己可见'),
            backgroundColor: Color(0xFFD4AF37),
          ),
        );
      }

      if (mounted && practice == null) {
        _showCompletionDialog(result);
      }
    }

    setState(() {});
  }

  Future<bool> _syncToCloud(SessionResult result, {String? notes}) async {
    try {
      final authModel = context.read<AuthModel>();
      if (!authModel.isLoggedIn || authModel.authToken == null) return false;

      final service = PracticeStatsService();
      service.setAuthToken(authModel.authToken);

      final saved = await service.syncRecord(
        sutra: result.sutra ?? '默认功课',
        sutraSource: 'auto',
        chantCount: result.chantCount > 0 ? result.chantCount : 1,
        duration: result.duration.inMinutes,
        startTime: result.startTime,
        endTime: result.endTime,
        notes: notes,
      );

      debugPrint(service.lastWriteQueued ? '🧘 修行记录已加入云端待同步' : '🧘 修行记录已同步到云端');
      return saved;
    } catch (e) {
      debugPrint('⚠️ 同步失败: $e');
      return false;
    }
  }

  void _showCompletionDialog(SessionResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🙏', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            const Text(
              '功德圆满',
              style: TextStyle(color: Colors.white, fontSize: 22),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('修行时长', result.formattedDuration),
            _buildStatRow('念诵遍数', '${result.chantCount}'),
            _buildStatRow('功课', result.sutra ?? '默认功课'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '随喜功德',
              style: TextStyle(color: Color(0xFFD4AF37)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _autoStartMeditation(); // 再次开始
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
            ),
            child: const Text('继续修行', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7))),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleCircumambulation() {
    setState(() {
      _isCircumambulating = !_isCircumambulating;
    });
    _buddhaKey.currentState?.setAutoRotate(_isCircumambulating);
  }

  /// 显示功课选择（高级选项）
  // ignore: unused_element
  void _showSutraSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 手柄
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                '更换功课',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '当前: ${_sessionManager.currentSutra}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // 常用功课快捷选择
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: SutraLibrary.sutras.length,
                  itemBuilder: (context, index) {
                    final sutra = SutraLibrary.sutras[index];
                    final isSelected =
                        _sessionManager.currentSutra == sutra.title;
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFD4AF37).withOpacity(0.2)
                              : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.auto_stories,
                          color: isSelected
                              ? const Color(0xFFD4AF37)
                              : Colors.white54,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        sutra.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        sutra.category,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFFD4AF37),
                            )
                          : null,
                      onTap: () {
                        _sessionManager.changeSutra(sutra.title);
                        Navigator.pop(context);
                        setState(() {});
                      },
                    );
                  },
                ),
              ),

              // 手动输入选项
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_note,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
                title: const Text(
                  '手动输入',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  '自定义功课名称',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showManualInput();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示功课选择/信息
  void _showPracticeSelection() {
    if (_sessionManager.isPracticeLocked) {
      // 已锁定功课，显示当前功课信息
      final practice = _sessionManager.lockedPractice;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.auto_stories, color: Color(0xFFD4AF37), size: 28),
              SizedBox(width: 12),
              Text('当前功课', style: TextStyle(color: Colors.white, fontSize: 20)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                practice?.title ?? '未选择',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '功课已锁定，一门深入，长时熏修',
                        style: TextStyle(color: Colors.green, fontSize: 13),
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
              child: const Text(
                '知道了',
                style: TextStyle(color: Color(0xFFD4AF37)),
              ),
            ),
            if (practice != null && !practice.filePath.startsWith('manual:'))
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openSutraReader();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                ),
                child: const Text(
                  '阅读经文',
                  style: TextStyle(color: Colors.black),
                ),
              ),
          ],
        ),
      );
    } else {
      // 未选择功课，弹出必选弹窗（不可取消）
      showPracticeSelectionSheet(
        context,
        required: true, // 不可取消
        onSelected: () {
          if (mounted) setState(() {});
        },
      );
    }
  }

  void _showManualInput() {
    final controller = TextEditingController(
      text: _sessionManager.currentSutra,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('输入功课名称', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '如：金刚经、心经、大悲咒...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _sessionManager.changeSutra(name);
                setState(() {});
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
            ),
            child: const Text('确定', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  /// 点击屏幕计数（替代音量键）
  void _onTapCount() {
    if (_sessionManager.isInSession) {
      _sessionManager.incrementChant();

      // 触感反馈
      HapticFeedback.lightImpact();

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _sessionManager,
      builder: (context, _) {
        final practice = _sessionManager.lockedPractice;
        return Stack(
          children: [
            // 背景：佛像3D场景
            Positioned.fill(
              child: GestureDetector(
                onTap: _onTapCount, // 点击屏幕计数
                child: BuddhaModelScreen(
                  key: _buddhaKey,
                  isVisible: _isPageVisible,
                  autoRotate: _isCircumambulating,
                  isBurning: _sessionManager.isInSession,
                  incenseProgress: _incenseController.value,
                  showBook: true,
                  bookTitle: practice?.title ?? '选择功课',
                  onBookTap:
                      practice == null ||
                          practice.filePath.startsWith('manual:')
                      ? _showPracticeSelection
                      : _openSutraReader,
                ),
              ),
            ),

            // 沉浸式遮罩
            if (_sessionManager.isInSession)
              Container(color: Colors.black.withOpacity(0.15)),

            // UI 覆盖层
            Positioned.fill(
              child: SafeArea(
                child: Stack(
                  children: [
                    // 顶部导航栏 (在线人数、排行、计时) - 绝对定位在顶部
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildTopBar(),
                    ),

                    // 中间点击计数区
                    if (_sessionManager.isInSession)
                      Center(child: _buildCenterContent()),

                    // 底部控制区
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildBottomControls(),
                    ),
                  ],
                ),
              ),
            ),

            // 欢迎提示（首次进入）
            if (!_isInitialized) _buildLoadingOverlay(),
          ],
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // 在线人数
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.36),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.22),
              ),
            ),
            child: CompactOnlineCounterWidget(
              countStream: _onlineCounterService.onlineCountStream,
              initialCount: _onlineCounterService.currentCount,
              icon: Icons.self_improvement,
              color: const Color(0xFFD4AF37),
            ),
          ),
          const SizedBox(width: 8),

          _buildTopIconButton(
            icon: Icons.leaderboard,
            tooltip: '修行排行',
            onTap: _showPracticeLeaderboard,
          ),
          const Spacer(),

          // 修行时长（正向计时）
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final isActive = _sessionManager.isInSession;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive
                        ? Color.lerp(
                            Colors.white24,
                            const Color(0xFFD4AF37),
                            _pulseController.value,
                          )!
                        : Colors.white24,
                    width: 0.5,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFD4AF37,
                            ).withOpacity(0.2 * _pulseController.value),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? Icons.timer : Icons.timer_outlined,
                      color: isActive
                          ? const Color(0xFFD4AF37)
                          : Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(_sessionManager.currentDuration),
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPracticeLeaderboard() {
    PracticeLeaderboardSheet.show(context);
  }

  Widget _buildTopIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.36),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 0.5),
          ),
          child: Icon(icon, color: Colors.white70, size: 21),
        ),
      ),
    );
  }

  Widget _buildCenterContent() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 点击计数提示
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Opacity(
                opacity: 0.3 + _pulseController.value * 0.3,
                child: const Text(
                  '点击屏幕计数',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // 大数字计数器
          GestureDetector(
            onTap: _onTapCount,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withOpacity(0.3),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_sessionManager.chantCount}',
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '遍',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 底部按钮行
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 左侧：功课选择/查看按钮
              _buildSideButton(
                icon: Icons.auto_stories,
                isActive: _sessionManager.isPracticeLocked,
                onTap: _showPracticeSelection,
              ),

              const SizedBox(width: 16),

              // 中间：结束修行按钮
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    if (_sessionManager.isInSession) {
                      await _endMeditation();
                    } else {
                      await _autoStartMeditation();
                    }
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _sessionManager.isInSession
                            ? [const Color(0xFF8B3A3A), const Color(0xFF602020)]
                            : [
                                const Color(0xFFD4AF37),
                                const Color(0xFFA67C00),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_sessionManager.isInSession
                                      ? Colors.red
                                      : const Color(0xFFD4AF37))
                                  .withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _sessionManager.isInSession
                              ? Icons.stop_circle_outlined
                              : Icons.play_circle_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _sessionManager.isInSession ? '结束修行' : '开始修行',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // 右侧：绕佛按钮
              _buildSideButton(
                icon: Icons.rotate_right,
                isActive: _isCircumambulating,
                onTap: _toggleCircumambulation,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSideButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFD4AF37).withOpacity(0.2)
              : Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? const Color(0xFFD4AF37) : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? const Color(0xFFD4AF37) : Colors.white70,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFD4AF37)),
            SizedBox(height: 16),
            Text('正在进入禅室...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
