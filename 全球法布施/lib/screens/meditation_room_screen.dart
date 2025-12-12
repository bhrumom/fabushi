import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import '../models/auth_model.dart';
import '../models/sutra_model.dart';
import '../services/cloudflare_worker_service.dart';
import '../services/practice_stats_service.dart';
import 'buddha_model_screen.dart';
import 'asset_screen.dart';
import '../services/online_counter_service.dart';
import '../widgets/online_counter_widget.dart';

// 香已集成到佛像3D场景中

class MeditationRoomScreen extends StatefulWidget {
  const MeditationRoomScreen({Key? key}) : super(key: key);

  @override
  State<MeditationRoomScreen> createState() => _MeditationRoomScreenState();
}

class _MeditationRoomScreenState extends State<MeditationRoomScreen> with TickerProviderStateMixin {
  // 状态变量
  bool _isMeditating = false;
  int _chantCount = 0;
  Sutra? _selectedSutra;
  String? _customSutraName; // 手动输入的功课名称
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  static const Duration _targetDuration = Duration(minutes: 30);
  bool _isCircumambulating = false; // 绕佛状态
  
  // 动画控制器
  late AnimationController _incenseController;
  
  // 佛像组件的 Key（保留用于手动控制，但主要通过参数控制）
  final GlobalKey<BuddhaModelScreenState> _buddhaKey = GlobalKey();
  
  // 服务
  final CloudflareWorkerService _apiService = CloudflareWorkerService();
  final _onlineCounterService = OnlineCounterService();

  @override
  void initState() {
    super.initState();
    _incenseController = AnimationController(
      vsync: this,
      duration: _targetDuration,
    );
    
    // 监听香燃烧进度，更新佛像场景中的香
    _incenseController.addListener(_onIncenseProgressChanged);
    
    // 初始化音量监听
    _initVolumeListener();
    
    // 获取初始在线人数
    _fetchInitialCount();
  }
  
  void _onIncenseProgressChanged() {
    // 直接更新佛像场景中的香进度
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
        if (_isMeditating) {
          setState(() {
            _chantCount++;
          });
        }
      });
    } catch (e) {
      debugPrint('音量监听初始化失败: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _incenseController.removeListener(_onIncenseProgressChanged);
    _incenseController.dispose();
    FlutterVolumeController.removeListener();
    _onlineCounterService.dispose();
    super.dispose();
  }

  // 防抖和异步操作标志
  bool _isProcessingMeditation = false;
  Future<void>? _joinFuture;

  void _toggleMeditation() {
    if (_isProcessingMeditation) return; // 防止快速连续点击
    
    if (_isMeditating) {
      _stopMeditation();
    } else {
      _startMeditation();
    }
  }

  void _startMeditation() async {
    _isProcessingMeditation = true;
    
    setState(() {
      _isMeditating = true;
      _elapsedTime = Duration.zero;
      _chantCount = 0;
    });
    _incenseController.forward(from: 0);
    
    // 加入禅室活动（保存 Future 以便停止时等待）
    _joinFuture = Future(() async {
      await _onlineCounterService.joinActivity('zen_room');
    });
    await _joinFuture;
    _joinFuture = null;
    
    _isProcessingMeditation = false;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime += const Duration(seconds: 1);
      });

      if (_elapsedTime >= _targetDuration) {
        _finishMeditation();
      }
    });
  }

  void _stopMeditation() async {
    _isProcessingMeditation = true;
    
    _timer?.cancel();
    _incenseController.stop();
    debugPrint('🛑 停止修行，绕佛状态: $_isCircumambulating');
    setState(() {
      _isMeditating = false;
      // 绕佛状态保持独立，不随修行停止而停止
    });
    debugPrint('🛑 停止修行后，绕佛状态: $_isCircumambulating');
    
    // 如果 join 还在进行中，等待它完成
    if (_joinFuture != null) {
      await _joinFuture;
    }
    
    // 稍微延迟确保服务端已记录session
    await Future.delayed(const Duration(milliseconds: 200));
    
    // 离开禅室活动
    await _onlineCounterService.leaveActivity();
    
    _isProcessingMeditation = false;
  }

  Future<void> _finishMeditation() async {
    _stopMeditation();
    
    // 显示完成对话框
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('功德圆满'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 16),
            Text('您已完成30分钟修行'),
            SizedBox(height: 8),
            Text('正在同步数据...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );

    // 同步数据
    await _syncData();

    if (!mounted) return;
    Navigator.of(context).pop(); // 关闭对话框
  }

  Future<void> _syncData() async {
    final authModel = context.read<AuthModel>();
    if (!authModel.isLoggedIn || authModel.authToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未登录，无法同步记录')),
      );
      return;
    }

    // 获取功课名称
    final sutraName = _currentSutraName;
    if (sutraName == '选择功课' || sutraName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择功课')),
      );
      return;
    }

    // 使用PracticeStatsService同步
    final service = PracticeStatsService();
    service.setAuthToken(authModel.authToken);
    
    final sutraSource = _selectedSutra != null ? 'asset' : 'custom';
    final success = await service.syncRecord(
      sutra: sutraName,
      sutraSource: sutraSource,
      chantCount: _chantCount > 0 ? _chantCount : 1, // 最少记1部
      duration: _targetDuration.inMinutes,
    );
    
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('修行记录已同步'), backgroundColor: Colors.green),
      );
    } else {
      // 回退到原始方法
      final recordData = {
        'duration': _targetDuration.inMinutes,
        'chantCount': _chantCount,
        'sutra': sutraName,
        'timestamp': DateTime.now().toIso8601String(),
      };
      final result = await _apiService.syncMeditationRecord(authModel.authToken!, recordData);
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('修行记录已同步')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: ${result['message']}')),
        );
      }
    }
  }

  void _toggleCircumambulation() {
    setState(() {
      _isCircumambulating = !_isCircumambulating;
    });
    debugPrint('🔄 绕佛切换: $_isCircumambulating');
    // 同时通过 GlobalKey 直接调用，确保状态同步
    _buddhaKey.currentState?.setAutoRotate(_isCircumambulating);
  }

  /// 获取当前功课名称
  String get _currentSutraName {
    if (_selectedSutra != null) return _selectedSutra!.title;
    if (_customSutraName != null && _customSutraName!.isNotEmpty) return _customSutraName!;
    return '选择功课';
  }

  /// 显示功课选择底部弹窗
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
                '选择修行功课',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              
              // 两种选择方式
              Row(
                children: [
                  Expanded(
                    child: _buildSelectionOption(
                      icon: Icons.library_books,
                      title: '从素材库选择',
                      subtitle: '选择首页的经文素材',
                      onTap: () {
                        Navigator.pop(context);
                        _showAssetSelection();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSelectionOption(
                      icon: Icons.edit_note,
                      title: '手动输入',
                      subtitle: '自定义功课名称',
                      onTap: () {
                        Navigator.pop(context);
                        _showManualInput();
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              
              // 常用功课快捷选择
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('常用功课', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
              const SizedBox(height: 12),
              
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: SutraLibrary.sutras.length,
                  itemBuilder: (context, index) {
                    final sutra = SutraLibrary.sutras[index];
                    final isSelected = _selectedSutra?.title == sutra.title;
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFE74C3C).withOpacity(0.2) : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.auto_stories,
                          color: isSelected ? const Color(0xFFE74C3C) : Colors.white54,
                          size: 20,
                        ),
                      ),
                      title: Text(sutra.title, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(sutra.category, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFFE74C3C)) : null,
                      onTap: () {
                        setState(() {
                          _selectedSutra = sutra;
                          _customSutraName = null;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFE74C3C), size: 24),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  /// 从素材库选择（使用AssetScreen）
  void _showAssetSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssetScreen(),
      ),
    ).then((result) {
      // 如果AssetScreen返回了选中的素材，可以处理
      // 目前AssetScreen主要用于下载，这里先使用弹窗方式
    });
  }

  /// 手动输入功课名称
  void _showManualInput() {
    final controller = TextEditingController(text: _customSutraName);
    
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
                setState(() {
                  _customSutraName = name;
                  _selectedSutra = null;
                });
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 背景：佛像和香（香集成在3D场景中，香一直显示，燃烧状态由isBurning控制）
        Positioned.fill(
          child: BuddhaModelScreen(
            key: _buddhaKey,
            autoRotate: _isCircumambulating,
            isBurning: _isMeditating,
            incenseProgress: _incenseController.value,
          ),
        ),
        
        // 遮罩层 (当修行开始时稍微变暗，突出前景)
        if (_isMeditating)
          Container(
            color: Colors.black.withOpacity(0.2),
          ),

        // UI 覆盖层
        SafeArea(
          child: Column(
            children: [
              // Top status bar - 只保留在线人数和计时器
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Online Count
                    Flexible(
                      child: OnlineCounterWidget(
                        countStream: _onlineCounterService.onlineCountStream,
                        initialCount: _onlineCounterService.currentCount,
                        icon: Icons.self_improvement,
                        prefix: '🧘',
                        color: const Color(0xFFD4AF37),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Timer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${_elapsedTime.inMinutes.toString().padLeft(2, '0')}:${(_elapsedTime.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.w600, 
                              fontFamily: 'monospace'
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Chant Counter - Moved to Top Left to avoid center obstruction
              if (_isMeditating)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_chantCount',
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            '遍数',
                            style: TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const Spacer(),

              // Bottom Control Area - 三按钮对称布局
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 当前功课显示（小型文字标签）
                    if (!_isMeditating)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: _showSutraSelection,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_stories, color: Color(0xFFD4AF37), size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  _currentSutraName,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit, color: Colors.white38, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ),
                    
                    // 底部按钮行
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 左侧：功课选择按钮（圆形小按钮）
                        GestureDetector(
                          onTap: _isMeditating ? null : _showSutraSelection,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(_isMeditating ? 0.2 : 0.4),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isMeditating ? Colors.white12 : const Color(0xFFD4AF37).withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.auto_stories,
                              color: _isMeditating ? Colors.white24 : const Color(0xFFD4AF37),
                              size: 24,
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // 中间：Start/Stop Button (Main)
                        Expanded(
                          child: GestureDetector(
                            onTap: _toggleMeditation,
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isMeditating 
                                    ? [const Color(0xFF8B3A3A), const Color(0xFF602020)] // Dark Red
                                    : [const Color(0xFFD4AF37), const Color(0xFFA67C00)], // Gold
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isMeditating ? Colors.red : const Color(0xFFD4AF37)).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isMeditating ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isMeditating ? '结束修行' : '开始念经',
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
                        
                        // 右侧：Circumambulate Button (Icon only)
                        GestureDetector(
                          onTap: _toggleCircumambulation,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: _isCircumambulating 
                                  ? const Color(0xFFD4AF37).withOpacity(0.2)
                                  : Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isCircumambulating 
                                    ? const Color(0xFFD4AF37)
                                    : Colors.white24,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.rotate_right,
                              color: _isCircumambulating ? const Color(0xFFD4AF37) : Colors.white70,
                              size: 26,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
