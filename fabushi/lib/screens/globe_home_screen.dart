import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/file_transfer_model.dart';
import '../widgets/earth_globe_widget.dart';
import 'leaderboard_screen.dart';
import '../core/design_system/app_theme.dart';
import '../services/online_counter_service.dart';
import '../widgets/online_counter_widget.dart';
import '../widgets/auto_start_guide_dialog.dart';

class GlobeHomeScreen extends StatefulWidget {
  const GlobeHomeScreen({super.key});

  @override
  State<GlobeHomeScreen> createState() => GlobeHomeScreenState();
}

class GlobeHomeScreenState extends State<GlobeHomeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final GlobalKey<EarthGlobeWidgetState> _globeKey = GlobalKey();
  String _currentSendingCountry = '';
  final List<Map<String, dynamic>> _pendingBeams = [];
  bool _isGlobeLoaded = false;
  bool _isCallbackSetup = false;
  bool _isVisible = true;
  final _onlineCounterService = OnlineCounterService();

  void setVisible(bool visible) {
    if (_isVisible == visible) return;
    _isVisible = visible;
    debugPrint('🌍 地球页面可见性变化: $visible');

    _globeKey.currentState?.setRenderingPaused(!visible);
    if (visible) {
      _playPendingBeams();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGlobe();
    _fetchInitialCount();
    _onlineCounterService.startCountPolling('global_sending');
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupTransferBeamCallback() {
    if (_isCallbackSetup && _globeKey.currentState != null) {
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

      final state = _globeKey.currentState;

      if (_isVisible && state != null) {
        try {
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

    final state = _globeKey.currentState;
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
    super.build(context);

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
            color: Colors.transparent,
            child: _isGlobeLoaded
                ? LayoutBuilder(
                    builder: (context, constraints) {
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
                                Icon(
                                  Icons.public,
                                  size: 80,
                                  color: Colors.cyan,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  '🌍 地球组件加载中...',
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
                            '🌍 正在加载地球组件...',
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
                highlightColor: AppTheme.primaryColor.withOpacity(0.3),
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
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scripture.isEmpty
                                    ? '正在发送内容'
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
                                '目标: $_currentSendingCountry',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.78),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
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
                      color: Colors.amber.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withOpacity(0.35)),
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
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
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
                              Icon(
                                Icons.sync,
                                color: Colors.cyanAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '动态杨升激活: ${model.loopbackCount} 次',
                                style: TextStyle(
                                  color: Colors.cyanAccent.withOpacity(0.9),
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
                                      color: Colors.cyanAccent.withOpacity(0.5),
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
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.white.withOpacity(0.2),
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
                  const SizedBox(height: 12),
                  _buildSelectedContentTile(model),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
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
                                model.isFieldEnergyMode
                                    ? Icons.wifi_tethering
                                    : Icons.wifi_tethering_off,
                                color: model.isFieldEnergyMode
                                    ? Colors.purple
                                    : Colors.white70,
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
                                        color: model.isFieldEnergyMode
                                            ? Colors.purple
                                            : Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      model.isFieldEnergyMode &&
                                              model.hotspotMessage.isNotEmpty
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
                              if (!context.mounted) return;
                              if (model.needsHotspotGuide) {
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
                Row(
                  children: [
                    Expanded(
                      child: model.isPreparingSend
                          ? ElevatedButton.icon(
                              onPressed: null,
                              icon: const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              label: const Text(
                                '准备发送中',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            )
                          : model.isTransferring
                          ? ElevatedButton.icon(
                              onPressed: () => _stopSending(model),
                              icon: const Icon(Icons.stop, size: 18),
                              label: const Text(
                                '停止发送',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                backgroundColor: Colors.red.shade600,
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: () => _startSending(model),
                              icon: const Icon(Icons.send, size: 18),
                              label: const Text(
                                '开始发送',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
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

  Widget _buildSelectedContentTile(FileTransferModel model) {
    final hasContent = model.hasFiles;
    final title = hasContent ? model.selectedContentTitle : '选择发送内容';
    final subtitle = hasContent
        ? (model.selectedContentSubtitle.isEmpty
              ? '点此重新选择链接、文本、文件或佛像素材'
              : model.selectedContentSubtitle)
        : '链接、文本、本机文件或禅室佛像素材';
    final icon = _contentIcon(model.selectedContentKind);

    return Material(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: model.isPreparingSend
            ? null
            : () => _showSendContentSheet(model),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (hasContent && model.selectedContentKind.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              model.selectedContentKind,
                              style: TextStyle(
                                color: AppTheme.primaryColor.withOpacity(0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            title,
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (model.hasSelectedContentPreview) ...[
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '查看已读取内容',
                  icon: const Icon(Icons.visibility, color: Colors.white70),
                  onPressed: () => _showSelectedContentPreview(model),
                ),
              ],
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
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
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
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

  Future<bool> _showSendContentSheet(FileTransferModel model) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF171717),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.84,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '选择要全球发送的内容',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _SendSourceTile(
                  icon: Icons.link,
                  title: '输入链接',
                  subtitle: '读取链接正文，读取后可点开查看',
                  onTap: () async {
                    final navigator = Navigator.of(sheetContext);
                    final selected = await _inputSendLink(model);
                    if (navigator.mounted) navigator.pop(selected);
                  },
                ),
                _SendSourceTile(
                  icon: Icons.edit_note,
                  title: '输入文本',
                  subtitle: '发送手输或粘贴的文本',
                  onTap: () async {
                    final navigator = Navigator.of(sheetContext);
                    final selected = await _inputSendText(model);
                    if (navigator.mounted) navigator.pop(selected);
                  },
                ),
                _SendSourceTile(
                  icon: Icons.folder_open,
                  title: '选择本机文件',
                  subtitle: '发送手机本机文件',
                  onTap: () async {
                    final navigator = Navigator.of(sheetContext);
                    final before = model.selectedFiles.length;
                    await model.selectFiles();
                    if (navigator.mounted) {
                      navigator.pop(model.selectedFiles.length > before);
                    }
                  },
                ),
                _SendSourceTile(
                  icon: Icons.self_improvement,
                  title: '禅室佛像素材',
                  subtitle: '发送禅室当前佛像模型素材',
                  onTap: () async {
                    final navigator = Navigator.of(sheetContext);
                    final selected = await _selectBuddhaAsset(model);
                    if (navigator.mounted) navigator.pop(selected);
                  },
                ),
                if (model.linkHistory.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '链接历史',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...model.linkHistory
                      .take(8)
                      .map(
                        (entry) => _SendSourceTile(
                          icon: Icons.history,
                          title: entry.title.isEmpty ? entry.url : entry.title,
                          subtitle: entry.preview.isEmpty
                              ? entry.url
                              : entry.preview,
                          onTap: () async {
                            final navigator = Navigator.of(sheetContext);
                            final selected = await _selectLinkHistory(
                              model,
                              entry,
                            );
                            if (navigator.mounted) navigator.pop(selected);
                          },
                        ),
                      ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return result == true;
  }

  Future<bool> _inputSendText(FileTransferModel model) async {
    final titleController = TextEditingController();
    final textController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入发送文本'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                minLines: 6,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: '输入或粘贴要发送的内容',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'title': titleController.text.trim(),
              'text': textController.text.trim(),
            }),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result == null || (result['text'] ?? '').trim().isEmpty) return false;
    await model.addTextContentForSending(
      title: result['title'] ?? '',
      text: result['text'] ?? '',
    );
    return true;
  }

  Future<bool> _inputSendLink(FileTransferModel model) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入链接'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('读取'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return false;
    try {
      await model.addUrlContentForSending(url);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('链接读取失败: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  Future<bool> _selectLinkHistory(
    FileTransferModel model,
    LinkSendHistoryEntry entry,
  ) async {
    try {
      await model.addUrlContentForSending(entry.url);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('历史链接读取失败: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
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

  Future<bool> _selectBuddhaAsset(FileTransferModel model) async {
    try {
      await model.addZenBuddhaAssetForSending();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('佛像素材准备失败: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  void _startSending(FileTransferModel model) async {
    if (model.isPreparingSend || model.isTransferring) return;

    if (!model.hasFiles) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先点“选择发送内容”选择链接、文本、本机文件或禅室佛像素材。'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.black87,
          ),
        );
      }
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
    _globeKey.currentState?.clearBeams();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🌍 开始把所选内容发送到全部国家...'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.black87,
        ),
      );
    }

    await model.startGlobalTransfer();
    final sentCount = model.globalSentCount;

    await _onlineCounterService.leaveActivity();
    _globeKey.currentState?.clearBeams();

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
    }
  }

  void _stopSending(FileTransferModel model) async {
    model.stopTransfer();
    await _onlineCounterService.leaveActivity();
    _globeKey.currentState?.clearBeams();

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

class _SendSourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onTap;

  const _SendSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.16),
        foregroundColor: const Color(0xFFD4AF37),
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      onTap: onTap,
    );
  }
}
