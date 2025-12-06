import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import '../models/auth_model.dart';
import '../models/sutra_model.dart';
import '../services/cloudflare_worker_service.dart';
import 'buddha_model_screen.dart';
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

  void _toggleMeditation() {
    if (_isMeditating) {
      _stopMeditation();
    } else {
      _startMeditation();
    }
  }

  void _startMeditation() {
    setState(() {
      _isMeditating = true;
      _elapsedTime = Duration.zero;
      _chantCount = 0;
    });
    _incenseController.forward(from: 0);
    
    // 加入禅室活动
    _onlineCounterService.joinActivity('zen_room');
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime += const Duration(seconds: 1);
      });

      if (_elapsedTime >= _targetDuration) {
        _finishMeditation();
      }
    });
  }

  void _stopMeditation() {
    _timer?.cancel();
    _incenseController.stop();
    debugPrint('🛑 停止修行，绕佛状态: $_isCircumambulating');
    setState(() {
      _isMeditating = false;
      // 绕佛状态保持独立，不随修行停止而停止
    });
    debugPrint('🛑 停止修行后，绕佛状态: $_isCircumambulating');
    
    // 离开禅室活动
    _onlineCounterService.leaveActivity();
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

    final recordData = {
      'duration': _targetDuration.inMinutes,
      'chantCount': _chantCount,
      'sutra': _selectedSutra?.title ?? '无',
      'timestamp': DateTime.now().toIso8601String(),
    };

    final result = await _apiService.syncMeditationRecord(authModel.authToken!, recordData);
    
    if (!mounted) return;
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

  void _toggleCircumambulation() {
    setState(() {
      _isCircumambulating = !_isCircumambulating;
    });
    debugPrint('🔄 绕佛切换: $_isCircumambulating');
    // 同时通过 GlobalKey 直接调用，确保状态同步
    _buddhaKey.currentState?.setAutoRotate(_isCircumambulating);
  }

  void _showSutraSelection() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '选择修行经文',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: SutraLibrary.sutras.length,
                itemBuilder: (context, index) {
                  final sutra = SutraLibrary.sutras[index];
                  return ListTile(
                    title: Text(sutra.title),
                    subtitle: Text(sutra.category),
                    onTap: () {
                      setState(() {
                        _selectedSutra = sutra;
                      });
                      Navigator.pop(context);
                    },
                    trailing: _selectedSutra?.title == sutra.title
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
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
              // Top status bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    Row(
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

              // Bottom Control Area
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Start/Stop Button (Main)
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
                    
                    // Circumambulate Button (Icon only)
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}
