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

import '../widgets/incense_3d_widget.dart';

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
  
  // 动画控制器
  late AnimationController _incenseController;
  
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
    
    // 初始化音量监听
    _initVolumeListener();
    
    // 获取初始在线人数
    _fetchInitialCount();
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
    setState(() {
      _isMeditating = false;
    });
    
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
        // 背景：佛像
        const BuddhaModelScreen(),
        
        // 遮罩层 (当修行开始时稍微变暗，突出前景)
        if (_isMeditating)
          Container(
            color: Colors.black.withOpacity(0.3),
          ),

        // 3D 香 (左侧)
        if (_isMeditating)
          Positioned(
            left: 20,
            bottom: 100,
            width: 100,
            height: 400,
            child: AnimatedBuilder(
              animation: _incenseController,
              builder: (context, child) {
                return Incense3DWidget(progress: _incenseController.value);
              },
            ),
          ),

        // UI 覆盖层
        SafeArea(
          child: Column(
            children: [
              // 顶部状态栏
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 在线人数显示
                    OnlineCounterWidget(
                      countStream: _onlineCounterService.onlineCountStream,
                      initialCount: _onlineCounterService.currentCount,
                      icon: Icons.self_improvement,
                      prefix: '🧘 正在修行:',
                      color: const Color(0xFFD4AF37),
                    ),
                    // 计时器
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_elapsedTime.inMinutes.toString().padLeft(2, '0')}:${(_elapsedTime.inSeconds % 60).toString().padLeft(2, '0')} / 30:00',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // 计数显示
              if (_isMeditating)
                Column(
                  children: [
                    const Text(
                      '念诵计数',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    Text(
                      '$_chantCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      '按音量+键计数',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),

              const SizedBox(height: 40),

              // 控制按钮
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: FloatingActionButton.extended(
                  onPressed: _toggleMeditation,
                  backgroundColor: _isMeditating ? Colors.red : const Color(0xFFD4AF37), // 金色
                  icon: Icon(_isMeditating ? Icons.stop : Icons.self_improvement),
                  label: Text(
                    _isMeditating ? '结束修行' : '开始念经',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
