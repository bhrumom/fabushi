import 'package:flutter/material.dart';
import 'package:global_dharma_sharing/core/design_system/colors.dart';
import 'package:global_dharma_sharing/services/sutra_listening_service.dart';

/// 听经页面 - 类似抖音听书的沉浸式朗读体验
///
/// 布局结构：
/// - 顶部：返回按钮 + 标题
/// - 中间：经文封面/当前句显示区
/// - 底部：进度指示 + 播放控制栏
class SutraListeningScreen extends StatefulWidget {
  final String sutraName;
  final String textContent;

  const SutraListeningScreen({
    required this.sutraName,
    required this.textContent,
    super.key,
  });

  @override
  State<SutraListeningScreen> createState() => _SutraListeningScreenState();
}

class _SutraListeningScreenState extends State<SutraListeningScreen>
    with SingleTickerProviderStateMixin {
  final SutraListeningService _service = SutraListeningService();
  late AnimationController _pulseController;

  // 语速选项
  static const List<double> _speedOptions = [0.3, 0.4, 0.55, 0.7, 0.9];
  static const List<String> _speedLabels = [
    '0.5x',
    '0.75x',
    '1.0x',
    '1.25x',
    '1.5x',
  ];
  int _currentSpeedIndex = 2; // 默认 1.0x (0.55)

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _service.addListener(_onServiceChanged);
    _startListening();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _startListening() async {
    await _service.startListening(
      name: widget.sutraName,
      textContent: widget.textContent,
    );
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _service.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: spaceDeepBlue,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏
            _buildTopBar(),

            // 中间内容区
            Expanded(child: _buildContentArea()),

            // 底部控制栏
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  /// 顶部导航栏
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '听经',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '支持后台播放',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          // 语速按钮
          GestureDetector(
            onTap: _cycleSpeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: glassSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: glassBorder),
              ),
              child: Text(
                _speedLabels[_currentSpeedIndex],
                style: TextStyle(
                  color: cosmicGold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 中间内容区域
  Widget _buildContentArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 经文封面/动画区域
          _buildSutraCover(),

          const SizedBox(height: 32),

          // 经文名称
          Text(
            widget.sutraName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // 当前朗读句
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Container(
              key: ValueKey(_service.currentSentenceIndex),
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Text(
                  _service.currentSentence,
                  style: TextStyle(
                    color: starlightWhite,
                    fontSize: 16,
                    height: 1.8,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 进度文字
          if (_service.totalSentences > 0)
            Text(
              '第 ${_service.currentSentenceIndex + 1} / ${_service.totalSentences} 句',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
        ],
      ),
    );
  }

  /// 经文封面区域
  Widget _buildSutraCover() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.03);
        return Transform.scale(
          scale: _service.isPlaying ? scale : 1.0,
          child: child,
        );
      },
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              nebulaPurple.withValues(alpha: 0.6),
              spaceBlue.withValues(alpha: 0.8),
              spaceDeepBlue,
            ],
            stops: const [0.3, 0.7, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: nebulaPurple.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.headphones, size: 56, color: cosmicGold),
              const SizedBox(height: 8),
              Text(
                _service.isPlaying
                    ? '朗读中...'
                    : (_service.isPaused ? '已暂停' : '准备中'),
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 底部播放控制
  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: spaceBlue.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          _buildProgressBar(),

          const SizedBox(height: 20),

          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 上一句
              _buildControlButton(
                icon: Icons.skip_previous_rounded,
                size: 32,
                onTap: _service.previousSentence,
                enabled: _service.currentSentenceIndex > 0,
              ),

              // 播放/暂停
              _buildPlayButton(),

              // 下一句
              _buildControlButton(
                icon: Icons.skip_next_rounded,
                size: 32,
                onTap: _service.nextSentence,
                enabled:
                    _service.currentSentenceIndex < _service.totalSentences - 1,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 进度条
  Widget _buildProgressBar() {
    final progress = _service.progress;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: cosmicGold,
            inactiveTrackColor: Colors.white12,
            thumbColor: cosmicGold,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 3,
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: (value) {
              final index = (value * _service.totalSentences).round().clamp(
                0,
                _service.totalSentences > 0 ? _service.totalSentences - 1 : 0,
              );
              _service.seekToSentence(index);
            },
          ),
        ),
      ],
    );
  }

  /// 播放/暂停按钮
  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: () => _service.togglePlayPause(),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [cosmicGold, cosmicGold.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: cosmicGold.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          _service.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: spaceDeepBlue,
          size: 36,
        ),
      ),
    );
  }

  /// 通用控制按钮
  Widget _buildControlButton({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Icon(
        icon,
        color: enabled ? Colors.white : Colors.white24,
        size: size,
      ),
    );
  }

  /// 循环语速
  void _cycleSpeed() {
    setState(() {
      _currentSpeedIndex = (_currentSpeedIndex + 1) % _speedOptions.length;
    });
    _service.setSpeechRate(_speedOptions[_currentSpeedIndex]);
  }
}
