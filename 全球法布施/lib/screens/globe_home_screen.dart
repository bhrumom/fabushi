import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_transfer_model.dart';
import '../widgets/earth_globe_widget.dart';
import 'leaderboard_screen.dart';

class GlobeHomeScreen extends StatefulWidget {
  const GlobeHomeScreen({super.key});

  @override
  State<GlobeHomeScreen> createState() => _GlobeHomeScreenState();
}

class _GlobeHomeScreenState extends State<GlobeHomeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  static EarthGlobeWidgetState? _globeState; // 静态引用，保持在页面切换时不丢失
  final GlobalKey<EarthGlobeWidgetState> _globeKey = GlobalKey();
  String _currentTransfer = '';
  final List<Map<String, dynamic>> _pendingBeams = []; // 缓存待播放的轨迹（包含标签）
  bool _isGlobeLoaded = false; // 地球组件是否已加载

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGlobe();
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
        _setupTransferBeamCallback();
      }
    }
  }

  @override
  void didUpdateWidget(GlobeHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 页面更新时重新设置回调
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupTransferBeamCallback();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupTransferBeamCallback() {
    // 更新静态引用
    if (_globeKey.currentState != null) {
      _globeState = _globeKey.currentState;
      debugPrint('🔗 更新 Globe 静态引用');
    }

    final model = Provider.of<FileTransferModel>(context, listen: false);
    model.setTransferBeamCallback((
      fromLat,
      fromLng,
      toLat,
      toLng, {
      String? fromLabel,
      String? toLabel,
    }) {
      // 优先使用静态引用
      final state = _globeState ?? _globeKey.currentState;
      debugPrint(
        '📡 轨迹回调触发: staticState=${_globeState != null}, keyState=${_globeKey.currentState != null}',
      );
      debugPrint('🏷️ 国家标签: $fromLabel -> $toLabel');

      if (state != null) {
        debugPrint('✅ 直接添加轨迹: $fromLabel ($fromLat, $fromLng) -> $toLabel ($toLat, $toLng)');
        try {
          state.addTransferBeam(
            fromLat,
            fromLng,
            toLat,
            toLng,
            color: Colors.cyan,
            duration: const Duration(seconds: 5),
            fromLabel: fromLabel,
            toLabel: toLabel,
          );
        } catch (e) {
          debugPrint('❌ 添加轨迹失败: $e');
        }
      } else {
        debugPrint('💾 缓存轨迹数据，等待页面可见');
        _pendingBeams.add({
          'fromLat': fromLat,
          'fromLng': fromLng,
          'toLat': toLat,
          'toLng': toLng,
          'fromLabel': fromLabel,
          'toLabel': toLabel,
        });
        if (_pendingBeams.length > 50) {
          _pendingBeams.removeAt(0);
        }
      }
    });

    _playPendingBeams();
    debugPrint('🔧 轨迹回调已设置');
  }

  void _playPendingBeams() {
    if (_pendingBeams.isEmpty) return;

    final state = _globeState ?? _globeKey.currentState;
    if (state == null) {
      debugPrint('⏳ Globe 还未准备好，稍后重试');
      Future.delayed(const Duration(milliseconds: 500), _playPendingBeams);
      return;
    }

    debugPrint('🎬 播放 ${_pendingBeams.length} 条缓存轨迹');
    for (final beam in _pendingBeams) {
      try {
        state.addTransferBeam(
          beam['fromLat'] as double,
          beam['fromLng'] as double,
          beam['toLat'] as double,
          beam['toLng'] as double,
          color: Colors.cyan,
          duration: const Duration(seconds: 5),
          fromLabel: beam['fromLabel'] as String?,
          toLabel: beam['toLabel'] as String?,
        );
      } catch (e) {
        debugPrint('❌ 播放缓存轨迹失败: $e');
      }
    }
    _pendingBeams.clear();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以保持状态

    // 每次 build 时重新设置回调，确保切换页面后回调仍然有效
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🔄 页面 build 完成，准备设置回调');
      _setupTransferBeamCallback();
    });

    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: const Color(0xFF0a0a0a),
            child: _isGlobeLoaded
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      debugPrint('🎭 Globe 渲染区域: ${constraints.maxWidth}x${constraints.maxHeight}');
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_globeKey.currentState != null && _globeState == null) {
                          _globeState = _globeKey.currentState;
                          debugPrint('💾 首次保存 Globe 静态引用');
                        }
                      });
                      
                      // 添加错误边界保护
                      try {
                        return EarthGlobeWidget(key: _globeKey);
                      } catch (e) {
                        debugPrint('⚠️ 地球组件渲染失败: $e');
                        return Container(
                          color: const Color(0xFF0a0a0a),
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
                    color: const Color(0xFF0a0a0a),
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
          Positioned(top: 60, left: 20, right: 20, child: _buildStatusBar()),

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
              style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.7)),
              tooltip: '排行榜',
            ),
          ),
          if (_currentTransfer.isNotEmpty)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _currentTransfer,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          Consumer<FileTransferModel>(
            builder: (context, model, _) {
              if (model.isTransferring) return const SizedBox.shrink();
              return Positioned(
                bottom: 100,
                left: 20,
                right: 20,
                child: _buildControlPanel(context),
              );
            },
          ),

        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return const SizedBox.shrink();
  }

  Widget _buildControlPanel(BuildContext context) {
    return Consumer<FileTransferModel>(
      builder: (context, model, _) {
        return Card(
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  model.selectedFile?.name ?? '未选择经文',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _selectFile(context),
                        icon: const Icon(Icons.menu_book),
                        label: const Text('选择经文'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: model.selectedFile != null && !model.isTransferring
                            ? () => _startSending(model)
                            : null,
                        icon: const Icon(Icons.send),
                        label: const Text('开始发送'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.green,
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

  void _startSending(FileTransferModel model) async {
    _globeKey.currentState?.clearBeams();

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
}
