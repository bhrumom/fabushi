import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 背诵游戏状态
enum RecitationState {
  idle,      // 空闲
  flashing,  // 闪现句子
  playing,   // 游戏中
  success,   // 成功
  failed,    // 失败
}

/// 背诵游戏组件
/// 
/// 功能：
/// 1. 快速闪过句子让用户记忆
/// 2. 打乱词序让用户按正确顺序点击
/// 3. 3次错误机会，全错重新闪现
/// 4. 15秒倒计时，超时重新闪现
class RecitationGameWidget extends StatefulWidget {
  const RecitationGameWidget({
    required this.sentence,
    super.key,
  });

  /// 要背诵的句子
  final String sentence;
  
  /// 从完整文本中提取正文（跳过经名、译者、品名）
  /// 格式示例：
  /// 大方广佛华严经卷第一
  /// 于阗国三藏实叉难陀奉制译
  /// 世主妙严品第一之一
  /// [正文开始...]
  static String extractMainText(String fullText) {
    if (fullText.isEmpty) return fullText;
    
    // 按换行符分割
    final lines = fullText.split(RegExp(r'[\n\r]+'));
    if (lines.length <= 1) {
      // 如果没有换行符，尝试按标点分割找正文
      return _extractFromSingleLine(fullText);
    }
    
    // 查找包含"译"字的行
    int startIndex = 0;
    for (int i = 0; i < lines.length && i < 5; i++) {
      final line = lines[i].trim();
      if (line.contains('译')) {
        // 找到译者行，正文从下一行或下下行开始
        startIndex = i + 1;
        // 检查下一行是否是品名（如"世主妙严品第一之一"）
        if (startIndex < lines.length && 
            lines[startIndex].contains('品') && 
            lines[startIndex].contains('第')) {
          startIndex++;
        }
        break;
      }
    }
    
    // 合并剩余行作为正文
    if (startIndex >= lines.length) {
      // 如果找不到正文，返回最后一部分
      return lines.last.trim();
    }
    
    return lines.skip(startIndex).join('\n').trim();
  }
  
  /// 从单行文本中提取正文（没有换行符的情况）
  static String _extractFromSingleLine(String text) {
    // 尝试找到"译"字后的内容
    final translateIndex = text.indexOf('译');
    if (translateIndex != -1 && translateIndex < text.length - 10) {
      // 跳过"译"字后可能的品名
      String remaining = text.substring(translateIndex + 1).trim();
      // 如果以"品"开头，尝试跳过品名
      if (remaining.contains('品') && remaining.contains('第')) {
        final match = RegExp(r'^.+?品第.+?之.+?\s*').firstMatch(remaining);
        if (match != null) {
          remaining = remaining.substring(match.end);
        }
      }
      if (remaining.isNotEmpty) {
        return remaining;
      }
    }
    return text;
  }

  @override
  State<RecitationGameWidget> createState() => _RecitationGameWidgetState();
}

class _RecitationGameWidgetState extends State<RecitationGameWidget>
    with TickerProviderStateMixin {
  /// 游戏状态
  RecitationState _state = RecitationState.idle;
  
  /// 原始词列表（正确顺序）
  List<String> _originalWords = [];
  
  /// 打乱后的词列表（带索引）
  List<_WordItem> _shuffledWords = [];
  
  /// 下一个需要选择的正确索引
  int _nextCorrectIndex = 0;
  
  /// 剩余错误机会
  int _remainingChances = 3;
  
  /// 剩余时间（秒）
  int _remainingTime = 15;
  
  /// 实际用于背诵的句子（提取后的正文）
  late String _actualSentence;
  
  /// 倒计时Timer
  Timer? _countdownTimer;
  
  /// 闪现动画控制器
  AnimationController? _flashController;
  Animation<double>? _flashAnimation;
  
  /// 成功/失败动画控制器
  AnimationController? _resultController;
  Animation<double>? _resultAnimation;

  @override
  void initState() {
    super.initState();
    // 提取正文
    _actualSentence = RecitationGameWidget.extractMainText(widget.sentence);
    _parseWords();
    _initAnimations();
    // 自动开始闪现
    Future.delayed(const Duration(milliseconds: 500), _startFlashing);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _flashController?.dispose();
    _resultController?.dispose();
    super.dispose();
  }

  /// 初始化动画控制器
  void _initAnimations() {
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _flashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController!, curve: Curves.easeInOut),
    );
    
    _resultController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _resultAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _resultController!, curve: Curves.elasticOut),
    );
  }

  /// 解析句子为词列表
  void _parseWords() {
    _originalWords = [];
    // 按字符拆分（中文逐字）
    for (int i = 0; i < _actualSentence.length; i++) {
      final char = _actualSentence[i];
      if (char.trim().isNotEmpty && !_isPunctuation(char)) {
        _originalWords.add(char);
      }
    }
  }
  
  /// 判断是否为标点符号
  bool _isPunctuation(String char) {
    const punctuations = '，。！？、；：""\'\'（）【】《》…—·．,.:;!?\'"()[]{}';
    return punctuations.contains(char);
  }

  /// 开始闪现阶段
  void _startFlashing() {
    setState(() {
      _state = RecitationState.flashing;
      _nextCorrectIndex = 0;
      _remainingTime = 15;
    });
    
    _flashController?.forward(from: 0.0);
    
    // 2秒后进入游戏阶段
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && _state == RecitationState.flashing) {
        _startPlaying();
      }
    });
  }

  /// 开始游戏阶段
  void _startPlaying() {
    // 创建带原始索引的词列表并打乱
    _shuffledWords = List.generate(
      _originalWords.length, 
      (i) => _WordItem(word: _originalWords[i], originalIndex: i, isSelected: false),
    );
    _shuffledWords.shuffle(Random());
    
    setState(() {
      _state = RecitationState.playing;
      _remainingTime = 15;
      _nextCorrectIndex = 0;
    });
    
    // 开始倒计时
    _startCountdown();
  }

  /// 开始倒计时
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _remainingTime--;
      });
      
      if (_remainingTime <= 0) {
        timer.cancel();
        _onTimeout();
      }
    });
  }

  /// 超时处理
  void _onTimeout() {
    HapticFeedback.heavyImpact();
    setState(() {
      _state = RecitationState.failed;
    });
    
    _resultController?.forward(from: 0.0);
    
    // 2秒后重新开始
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _remainingChances = 3;
        _startFlashing();
      }
    });
  }

  /// 处理用户点击词
  void _onWordTap(int shuffledIndex) {
    if (_state != RecitationState.playing) return;
    
    final item = _shuffledWords[shuffledIndex];
    if (item.isSelected) return;
    
    if (item.originalIndex == _nextCorrectIndex) {
      // 正确选择 - 标记为已选择（消失）
      HapticFeedback.lightImpact();
      setState(() {
        _shuffledWords[shuffledIndex] = item.copyWith(isSelected: true);
        _nextCorrectIndex++;
      });
      
      // 检查是否完成
      if (_nextCorrectIndex >= _originalWords.length) {
        _onSuccess();
      }
    } else {
      // 错误选择
      HapticFeedback.heavyImpact();
      setState(() {
        _remainingChances--;
      });
      
      if (_remainingChances <= 0) {
        _onAllChancesUsed();
      }
    }
  }

  /// 成功完成
  void _onSuccess() {
    _countdownTimer?.cancel();
    setState(() {
      _state = RecitationState.success;
    });
    
    _resultController?.forward(from: 0.0);
    
    // 2秒后返回
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  /// 所有机会用完
  void _onAllChancesUsed() {
    _countdownTimer?.cancel();
    setState(() {
      _state = RecitationState.failed;
    });
    
    _resultController?.forward(from: 0.0);
    
    // 2秒后重新开始
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _remainingChances = 3;
        _startFlashing();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '背诵练习',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case RecitationState.idle:
        return const Center(
          child: CircularProgressIndicator(color: Colors.amber),
        );
      case RecitationState.flashing:
        return _buildFlashingView();
      case RecitationState.playing:
        return _buildPlayingView();
      case RecitationState.success:
        return _buildSuccessView();
      case RecitationState.failed:
        return _buildFailedView();
    }
  }

  /// 闪现视图
  Widget _buildFlashingView() {
    return AnimatedBuilder(
      animation: _flashAnimation!,
      builder: (context, child) {
        return Center(
          child: Opacity(
            opacity: _flashAnimation!.value > 0.5 
                ? 2 * (1 - _flashAnimation!.value)
                : 2 * _flashAnimation!.value,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _actualSentence,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                  height: 1.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 游戏视图 - 简化版：只有中间的乱序词
  Widget _buildPlayingView() {
    return Column(
      children: [
        const SizedBox(height: 20),
        // 倒计时和机会显示
        _buildStatusBar(),
        // 进度提示
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text(
            '已完成 $_nextCorrectIndex / ${_originalWords.length}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ),
        // 乱序词显示在中间
        Expanded(
          child: Center(
            child: _buildCandidateWords(),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  /// 状态栏：倒计时 + 剩余机会
  Widget _buildStatusBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // 倒计时进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _remainingTime / 15,
              minHeight: 8,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(
                _remainingTime <= 5 ? Colors.red : Colors.amber,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 剩余时间和机会
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '剩余时间: $_remainingTime秒',
                style: TextStyle(
                  color: _remainingTime <= 5 ? Colors.red : Colors.white70,
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  const Text(
                    '机会: ',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  ...List.generate(3, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        index < _remainingChances ? Icons.favorite : Icons.favorite_border,
                        color: index < _remainingChances ? Colors.red : Colors.grey,
                        size: 20,
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 候选词按钮 - 点击正确的消失
  Widget _buildCandidateWords() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: List.generate(_shuffledWords.length, (index) {
          final item = _shuffledWords[index];
          if (item.isSelected) {
            // 已选择的词消失（用透明占位保持布局稳定）
            return const SizedBox.shrink();
          }
          return GestureDetector(
            onTap: () => _onWordTap(index),
            child: _buildWordButton(item.word),
          );
        }),
      ),
    );
  }

  /// 词按钮样式
  Widget _buildWordButton(String word) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        word,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  /// 成功视图
  Widget _buildSuccessView() {
    return AnimatedBuilder(
      animation: _resultAnimation!,
      builder: (context, child) {
        return Center(
          child: Transform.scale(
            scale: _resultAnimation!.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C853), Color(0xFF00E676)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '太棒了！',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '背诵成功',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 失败视图
  Widget _buildFailedView() {
    final message = _remainingChances <= 0 ? '机会用完了' : '时间到！';
    
    return AnimatedBuilder(
      animation: _resultAnimation!,
      builder: (context, child) {
        return Center(
          child: Transform.scale(
            scale: _resultAnimation!.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.refresh,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '重新开始...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 词条目数据类
class _WordItem {
  final String word;
  final int originalIndex;
  final bool isSelected;
  
  const _WordItem({
    required this.word,
    required this.originalIndex,
    required this.isSelected,
  });
  
  _WordItem copyWith({bool? isSelected}) {
    return _WordItem(
      word: word,
      originalIndex: originalIndex,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

