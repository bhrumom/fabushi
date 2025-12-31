import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_transfer_model.dart';
import '../widgets/earth_globe_widget.dart';
import 'leaderboard_screen.dart';
import '../core/design_system/app_theme.dart';
import '../services/online_counter_service.dart';
import '../widgets/online_counter_widget.dart';
import '../core/utils/auth_guard.dart';
import '../widgets/auto_start_guide_dialog.dart';

class GlobeHomeScreen extends StatefulWidget {
  const GlobeHomeScreen({super.key});

  @override
  State<GlobeHomeScreen> createState() => _GlobeHomeScreenState();
}

class _GlobeHomeScreenState extends State<GlobeHomeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  static EarthGlobeWidgetState? _globeState; // 静态引用，保持在页面切换时不丢失
  final GlobalKey<EarthGlobeWidgetState> _globeKey = GlobalKey();
  String _currentSendingCountry = ''; // 当前正在发送的国家
  final List<Map<String, dynamic>> _pendingBeams = []; // 缓存待播放的轨迹（包含标签）
  bool _isGlobeLoaded = false; // 地球组件是否已加载
  bool _isCallbackSetup = false; // 性能优化：防止重复设置回调
  final _onlineCounterService = OnlineCounterService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGlobe();
    _fetchInitialCount();
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
    // 延迟加载地球组件，先显示背景
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
          // 即使地球组件加载失败，也要显示界面
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
      // 应用恢复时重新加载
      if (!_isGlobeLoaded) {
        _loadGlobe();
      } else {
        // 性能优化：标记需要重新设置回调
        _isCallbackSetup = false;
        _setupTransferBeamCallback();
      }
    }
  }

  @override
  void didUpdateWidget(GlobeHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 页面更新时重新设置回调
    // 性能优化：标记需要重新设置回调
    _isCallbackSetup = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupTransferBeamCallback();
    });
  }

  @override
  void dispose() {
    _onlineCounterService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupTransferBeamCallback() {
    // 性能优化：如果回调已设置且Globe状态仍然有效，跳过重复设置
    if (_isCallbackSetup && _globeState != null && _globeKey.currentState != null) {
      return;
    }

    // 更新静态引用
    if (_globeKey.currentState != null) {
      _globeState = _globeKey.currentState;
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
      // 更新当前发送的国家名称
      if (toLabel != null && mounted) {
        setState(() {
          _currentSendingCountry = toLabel;
        });
      }

      // 优先使用静态引用
      final state = _globeState ?? _globeKey.currentState;

      if (state != null) {
        try {
          // 显示目标点和连线，使用实际发送时间作为显示时长
          state.addTransferBeam(
            fromLat,
            fromLng,
            toLat,
            toLng,
            duration: displayDuration ?? const Duration(milliseconds: 800),
            toLabel: toLabel,
          );
        } catch (e) {
          debugPrint('❌ 添加轨迹失败: $e');
        }
      } else {
        // 缓存数据，等待页面可见
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

    // 标记回调已设置
    _isCallbackSetup = true;
    _playPendingBeams();
  }

  void _playPendingBeams() {
    if (_pendingBeams.isEmpty) return;

    final state = _globeState ?? _globeKey.currentState;
    if (state == null) {
      Future.delayed(const Duration(milliseconds: 500), _playPendingBeams);
      return;
    }

    for (final beam in _pendingBeams) {
      try {
        state.addTransferBeam(
          beam['fromLat'] as double,
          beam['fromLng'] as double,
          beam['toLat'] as double,
          beam['toLng'] as double,
          duration: const Duration(seconds: 3),
          toLabel: beam['toLabel'] as String?,
        );
      } catch (e) {
        debugPrint('❌ 播放缓存目标点失败: $e');
      }
    }
    _pendingBeams.clear();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以保持状态

    // 性能优化：仅在回调未设置时才在 postFrameCallback 中设置
    if (!_isCallbackSetup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupTransferBeamCallback();
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            color: Colors.transparent, // Keep transparent to show SpaceBackground
            child: _isGlobeLoaded
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      // 保存 Globe 静态引用（移除调试日志以提升性能）
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_globeKey.currentState != null && _globeState == null) {
                          _globeState = _globeKey.currentState;
                        }
                      });
                      
                      // 添加错误边界保护
                      try {
                        return EarthGlobeWidget(key: _globeKey);
                      } catch (e) {
                        debugPrint('⚠️ 地球组件渲染失败: $e');
                        return Container(
                          color: Colors.transparent,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.public, size: 80, color: Colors.cyan),
                                SizedBox(height: 16),
                                Text(
                                  '🌍 地球组件加载中...',
                                  style: TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '请稍后或重启应用',
                                  style: TextStyle(color: Colors.white54, fontSize: 14),
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
                            '🌍 正在加载地球组件...',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '首次加载可能需要几秒钟',
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          // 在线人数显示
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
                  MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
                );
              },
              icon: const Icon(Icons.leaderboard, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.glassDecoration.color,
                highlightColor: AppTheme.primaryColor.withOpacity(0.3),
              ),
              tooltip: '排行榜',
            ),
          ),
          // 实时发送状态显示
          Consumer<FileTransferModel>(
            builder: (context, model, _) {
              if (!model.isTransferring || _currentSendingCountry.isEmpty) {
                return const SizedBox.shrink();
              }
              return Positioned(
                top: 70,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: AppTheme.glassDecoration.copyWith(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.cyan,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '正在发送到 $_currentSendingCountry',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // 控制面板 - 始终显示
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
                // 发送进度显示（发送中时显示在顶部）
                if (model.isTransferring) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.send, color: AppTheme.primaryColor, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  '已发送: ${model.globalSentCount} 个国家',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (model.loopCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '第 ${model.loopCount} 轮',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // 场能广播状态显示
                        if (model.isFieldEnergyMode && model.fieldBroadcastCount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.wifi_tethering, color: Colors.purple, size: 16),
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
                                      color: Colors.purple.withOpacity(0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        // 本地回环开启时，显示极速进行中（可选，用户说移除状态计数，我这里把整个状态行移除或保留纯状态）
                        // 根据用户要求“把本地回环的状态计数移除”，我将整个相关的 UI 块移除
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  // 未发送时显示文件名
                  Text(
                    model.selectedFile?.name ?? '未选择经文',
                    style: const TextStyle(
                      fontSize: 15, 
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  
                  // 循环发送开关（仅在未发送时显示）
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              model.isLooping ? Icons.repeat : Icons.repeat_one,
                              color: model.isLooping ? AppTheme.primaryColor : Colors.white70,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '循环发送',
                              style: TextStyle(
                                color: model.isLooping ? AppTheme.primaryColor : Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 28,
                          child: Switch(
                            value: model.isLooping,
                            onChanged: (value) => model.setLooping(value),
                            activeColor: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // 无网场能模式开关
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: model.isFieldEnergyMode 
                          ? Colors.purple.withOpacity(0.2)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: model.isFieldEnergyMode 
                          ? Border.all(color: Colors.purple.withOpacity(0.5))
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                model.isFieldEnergyMode ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                                color: model.isFieldEnergyMode ? Colors.purple : Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '无网场能模式',
                                      style: TextStyle(
                                        color: model.isFieldEnergyMode ? Colors.purple : Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      model.isFieldEnergyMode && model.hotspotMessage.isNotEmpty
                                          ? model.hotspotMessage
                                          : '自动开启热点向周围广播',
                                      style: TextStyle(
                                        color: model.isFieldEnergyMode 
                                            ? Colors.purple.withOpacity(0.7)
                                            : Colors.white54,
                                        fontSize: 10,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 28,
                          child: Switch(
                            value: model.isFieldEnergyMode,
                            onChanged: (value) async {
                              await model.setFieldEnergyMode(value);
                              // 如果需要显示热点指导，弹出指导弹窗
                              if (model.needsHotspotGuide && mounted) {
                                _showHotspotGuideDialog(context);
                                model.clearHotspotGuide();
                              }
                            },
                            activeColor: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // 按钮行
                Row(
                  children: [
                    // 选择经文按钮（发送中时禁用）
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: model.isTransferring ? null : () => _selectFile(context),
                        icon: Icon(Icons.menu_book, size: 18),
                        label: const Text('选择经文', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: model.isTransferring 
                              ? Colors.grey.withOpacity(0.3)
                              : AppTheme.secondaryColor.withOpacity(0.8),
                          disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 开始/停止按钮
                    Expanded(
                      child: model.isTransferring
                          ? ElevatedButton.icon(
                              onPressed: () => _stopSending(model),
                              icon: const Icon(Icons.stop, size: 18),
                              label: const Text('停止发送', style: TextStyle(fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                backgroundColor: Colors.red.shade600,
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: model.selectedFile != null
                                  ? () => _startSending(model)
                                  : null,
                              icon: const Icon(Icons.send, size: 18),
                              label: const Text('开始发送', style: TextStyle(fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                backgroundColor: AppTheme.primaryColor,
                              ),
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
  }

  void _selectFile(BuildContext context) async {
    final model = Provider.of<FileTransferModel>(context, listen: false);
    await model.selectBuiltInAssets(context);
  }

  /// 显示热点开启指导弹窗
  void _showHotspotGuideDialog(BuildContext context) {
    // 根据平台显示不同的指导内容
    String title;
    List<String> steps;
    String tip;
    
    if (kIsWeb) {
      return; // Web 平台不支持
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
      steps = [
        '1. 打开系统设置',
        '2. 找到网络或热点设置',
        '3. 开启 Wi-Fi 热点功能',
        '4. 返回本应用开始发送',
      ];
      tip = '💡 开启热点后，经文能量将通过 Wi-Fi 信号向周围空间广播';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ...steps.map((step) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            )),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.purple, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        color: Colors.purple[200],
                        fontSize: 12,
                      ),
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
              '稍后设置',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // 再次触发打开设置
              final model = Provider.of<FileTransferModel>(context, listen: false);
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

  void _startSending(FileTransferModel model) async {
    // 抖音风格：所有同步云端的活跃操作都需要登录
    final hasAuth = await AuthGuard.check(context);
    if (!hasAuth) return;

    // Android 平台：首次使用时显示自启动设置引导
    if (Platform.isAndroid && mounted) {
      await AutoStartGuideDialog.showIfNeeded(context);
    }

    _globeKey.currentState?.clearBeams();

    // 加入在线活动，增加在线人数
    await _onlineCounterService.joinActivity('global_sending');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🌍 开始向全球发送经文...'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.black87,
        ),
      );
    }

    // 开始真实的全球发送，轨迹动画将自动触发
    await model.startGlobalTransfer();

    // 发送完成后离开在线活动
    await _onlineCounterService.leaveActivity();

    // 发送完成后清除轨迹
    _globeKey.currentState?.clearBeams();
    
    // 清除当前发送状态
    if (mounted) {
      setState(() {
        _currentSendingCountry = '';
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ 经文已成功发送到全球 ${model.globalSentCount} 个国家！'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _stopSending(FileTransferModel model) async {
    model.stopTransfer();
    
    // 离开在线活动，减少在线人数
    await _onlineCounterService.leaveActivity();
    
    // 清除轨迹
    _globeKey.currentState?.clearBeams();
    
    // 清除当前发送状态
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
