import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../../services/sherpa_stt_service.dart';
import '../../../../../services/audio_stream_service.dart';

/// 音频时间戳标记（用于播放时文本同步）
class AudioMarker {
  final int sentenceIndex;
  final int startMs;
  final int endMs;

  AudioMarker({
    required this.sentenceIndex,
    required this.startMs,
    required this.endMs,
  });

  Map<String, dynamic> toJson() => {
    'sentenceIndex': sentenceIndex,
    'startMs': startMs,
    'endMs': endMs,
  };

  factory AudioMarker.fromJson(Map<String, dynamic> json) => AudioMarker(
    sentenceIndex: json['sentenceIndex'] as int,
    startMs: json['startMs'] as int,
    endMs: json['endMs'] as int,
  );
}

/// 读诵游戏状态
enum ReadingState {
  idle,          // 空闲，等待开始
  initializing,  // 正在初始化
  listening,     // 正在录音和识别
  processing,    // 处理识别结果
  switching,     // 切换到下一句
  completed,     // 全部完成
  error,         // 错误
}

/// 读诵游戏结果
class ReadingResult {
  final String? audioPath;
  final List<AudioMarker> markers;
  final Duration totalDuration;

  ReadingResult({
    this.audioPath,
    required this.markers,
    required this.totalDuration,
  });
}

/// 读诵游戏组件
/// 
/// 功能：
/// 1. 逐句显示经文，高亮当前句
/// 2. 使用 Vosk 离线语音识别，智能检测念诵进度
/// 3. 念完自动切换下一句（秒级响应）
/// 4. 全程录音，支持导出
class ReadingGameWidget extends StatefulWidget {
  const ReadingGameWidget({
    required this.sentences,
    required this.contentId,
    this.onComplete,
    super.key,
  });

  /// 句子列表
  final List<String> sentences;
  
  /// 内容ID（用于评论关联）
  final String contentId;
  
  /// 完成回调
  final void Function(ReadingResult result)? onComplete;

  @override
  State<ReadingGameWidget> createState() => _ReadingGameWidgetState();
}

class _ReadingGameWidgetState extends State<ReadingGameWidget>
    with TickerProviderStateMixin {
  /// 读诵状态
  ReadingState _state = ReadingState.idle;
  
  /// 当前句子索引
  int _currentIndex = 0;
  
  /// 音频流服务
  final AudioStreamService _audioService = AudioStreamService.instance;
  
  /// 语音识别服务
  final SherpaSTTService _sttService = SherpaSTTService.instance;
  
  /// 音频流订阅
  StreamSubscription<Uint8List>? _audioSubscription;
  
  /// 录音文件路径
  String? _audioPath;
  
  /// 时间戳标记
  final List<AudioMarker> _markers = [];
  
  /// 当前句子开始时间
  DateTime? _sentenceStartTime;
  
  /// 录音开始时间
  DateTime? _recordingStartTime;
  
  /// 识别到的文本
  String _recognizedText = '';
  
  /// 错误信息
  String? _errorMessage;
  
  /// 初始化进度消息
  String _initMessage = '';
  
  /// 动画控制器
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;
  
  /// 进度动画控制器
  AnimationController? _progressController;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initServices();
  }

  @override
  void dispose() {
    _stopAll();
    _pulseController?.dispose();
    _progressController?.dispose();
    super.dispose();
  }

  /// 初始化动画
  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  /// 初始化服务
  Future<void> _initServices() async {
    debugPrint('[ReadingGame] === 开始初始化 ===');
    
    setState(() {
      _state = ReadingState.initializing;
      _initMessage = '正在请求麦克风权限...';
    });
    
    try {
      // 1. 请求麦克风权限
      debugPrint('[ReadingGame] 步骤1: 请求麦克风权限...');
      final micStatus = await Permission.microphone.request()
          .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('[ReadingGame] 警告: 麦克风权限请求超时');
        return PermissionStatus.denied;
      });
      debugPrint('[ReadingGame] 麦克风权限状态: $micStatus');
      
      if (!micStatus.isGranted) {
        debugPrint('[ReadingGame] 错误: 麦克风权限未授予');
        if (mounted) {
          setState(() {
            _state = ReadingState.error;
            _errorMessage = '需要麦克风权限才能使用读诵功能\n请在设置中授予权限后重试';
          });
        }
        return;
      }
      
      // 2. 初始化音频服务
      setState(() {
        _initMessage = '正在初始化音频服务...';
      });
      debugPrint('[ReadingGame] 步骤2: 初始化音频服务...');
      final audioSuccess = await _audioService.initialize();
      if (!audioSuccess) {
        if (mounted) {
          setState(() {
            _state = ReadingState.error;
            _errorMessage = '音频服务初始化失败';
          });
        }
        return;
      }
      
      // 3. 初始化语音识别服务
      setState(() {
        _initMessage = '正在加载语音识别模型...\n（首次使用需下载约50MB模型）';
      });
      debugPrint('[ReadingGame] 步骤3: 初始化 Vosk 语音识别...');
      
      // 设置识别回调
      _sttService.onResult = _onRecognitionResult;
      _sttService.onError = (error) {
        debugPrint('[ReadingGame] 识别错误: $error');
      };
      
      final sttSuccess = await _sttService.initialize();
      if (!sttSuccess) {
        if (mounted) {
          setState(() {
            _state = ReadingState.error;
            _errorMessage = '语音识别初始化失败\n请检查网络连接后重试';
          });
        }
        return;
      }
      
      debugPrint('[ReadingGame] === 初始化完成 ===');
      if (mounted) {
        setState(() {
          _state = ReadingState.idle;
          _initMessage = '';
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[ReadingGame] 初始化异常: $e');
      debugPrint('[ReadingGame] 堆栈: $stackTrace');
      if (mounted) {
        setState(() {
          _state = ReadingState.error;
          _errorMessage = '初始化失败: $e';
        });
      }
    }
  }

  /// 开始读诵
  Future<void> _startReading() async {
    try {
      // 开始录音并获取音频流
      final stream = await _audioService.startRecording(saveToFile: true);
      if (stream == null) {
        _showError('开始录音失败');
        return;
      }
      
      _recordingStartTime = DateTime.now();
      _audioPath = _audioService.currentRecordingPath;
      
      // 启动语音识别
      await _sttService.startRecognizing();
      
      // 订阅音频流，发送到识别器
      _audioSubscription = stream.listen((audioData) {
        _sttService.processAudio(audioData);
      });
      
      setState(() {
        _state = ReadingState.listening;
        _currentIndex = 0;
        _recognizedText = '';
        _markers.clear();
      });
      
      _sentenceStartTime = DateTime.now();
      HapticFeedback.lightImpact();
      
      debugPrint('[ReadingGame] 开始监听第 1 句: "${widget.sentences[0]}"');
    } catch (e) {
      debugPrint('[ReadingGame] 开始读诵异常: $e');
      _showError('开始读诵失败: $e');
    }
  }

  /// 语音识别结果回调
  void _onRecognitionResult(String text, bool isFinal) {
    if (!mounted || _state != ReadingState.listening) return;
    
    debugPrint('[ReadingGame] 识别结果: "$text" (final: $isFinal)');
    
    setState(() {
      _recognizedText = text;
    });
    
    // 检查是否念完当前句子
    if (_checkSentenceCompleted(text)) {
      debugPrint('[ReadingGame] 句子匹配成功！');
      _onSentenceCompleted();
    }
  }

  /// 检查是否念完当前句子
  /// 使用模糊匹配，允许一定程度的识别误差
  bool _checkSentenceCompleted(String recognized) {
    if (recognized.isEmpty) return false;
    
    final currentSentence = widget.sentences[_currentIndex];
    
    // 移除标点符号进行比较
    final cleanRecognized = _cleanText(recognized);
    final cleanSentence = _cleanText(currentSentence);
    
    if (cleanSentence.isEmpty) return true;
    
    // 计算相似度
    final similarity = _calculateSimilarity(cleanRecognized, cleanSentence);
    
    // 相似度超过 70% 认为念完
    // 或者识别文本长度接近目标长度
    final lengthRatio = cleanRecognized.length / cleanSentence.length;
    
    return similarity > 0.7 || (lengthRatio >= 0.8 && similarity > 0.5);
  }

  /// 清理文本（移除标点和空格）
  String _cleanText(String text) {
    return text.replaceAll(RegExp(r'[，。！？、；：""''（）【】《》…\s]'), '');
  }

  /// 计算字符串相似度（简单的字符匹配）
  double _calculateSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    
    int matches = 0;
    final shorter = a.length < b.length ? a : b;
    final longer = a.length < b.length ? b : a;
    
    for (int i = 0; i < shorter.length; i++) {
      if (longer.contains(shorter[i])) {
        matches++;
      }
    }
    
    return matches / shorter.length;
  }

  /// 当前句子念完
  void _onSentenceCompleted() async {
    HapticFeedback.mediumImpact();
    
    // 重置识别器
    _sttService.reset();
    
    // 记录时间戳标记
    final now = DateTime.now();
    final startMs = _sentenceStartTime!.difference(_recordingStartTime!).inMilliseconds;
    final endMs = now.difference(_recordingStartTime!).inMilliseconds;
    
    _markers.add(AudioMarker(
      sentenceIndex: _currentIndex,
      startMs: startMs,
      endMs: endMs,
    ));
    
    setState(() {
      _state = ReadingState.switching;
      _currentIndex++;
    });
    
    // 短暂延迟后切换到下一句
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (_currentIndex >= widget.sentences.length) {
      _completeReading();
    } else if (mounted) {
      setState(() {
        _state = ReadingState.listening;
        _recognizedText = '';
      });
      _sentenceStartTime = DateTime.now();
      debugPrint('[ReadingGame] 开始监听第 ${_currentIndex + 1} 句: "${widget.sentences[_currentIndex]}"');
    }
  }

  /// 完成读诵
  Future<void> _completeReading() async {
    try {
      // 停止识别和录音
      await _sttService.stopRecognizing();
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      
      final path = await _audioService.stopRecording();
      
      setState(() {
        _state = ReadingState.completed;
      });
      
      HapticFeedback.heavyImpact();
      
      // 延迟后显示结果
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        final totalDuration = DateTime.now().difference(_recordingStartTime!);
        final result = ReadingResult(
          audioPath: path,
          markers: _markers,
          totalDuration: totalDuration,
        );
        
        _showCompletionDialog(result);
      }
    } catch (e) {
      debugPrint('完成读诵异常: $e');
    }
  }

  /// 显示完成对话框
  void _showCompletionDialog(ReadingResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('读诵完成！', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '读诵时长: ${_formatDuration(result.totalDuration)}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              '共 ${widget.sentences.length} 句',
              style: const TextStyle(color: Colors.white70),
            ),
            if (result.audioPath != null) ...[
              const SizedBox(height: 8),
              const Text(
                '录音已保存 ✓',
                style: TextStyle(color: Colors.green),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(this.context).pop();
            },
            child: const Text('完成', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(this.context).pop();
              widget.onComplete?.call(result);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('发布到评论'),
          ),
        ],
      ),
    );
  }

  /// 格式化时长
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes 分 $seconds 秒';
  }

  /// 停止所有
  Future<void> _stopAll() async {
    try {
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      
      await _sttService.stopRecognizing();
      await _audioService.stopRecording();
    } catch (e) {
      debugPrint('停止异常: $e');
    }
  }

  /// 显示错误
  void _showError(String message) {
    setState(() {
      _state = ReadingState.error;
      _errorMessage = message;
    });
  }

  /// 手动跳过当前句子
  void _skipCurrentSentence() {
    if (_state == ReadingState.listening) {
      _onSentenceCompleted();
    }
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
          onPressed: () async {
            final navigator = Navigator.of(context);
            await _stopAll();
            if (!mounted) return;
            navigator.pop();
          },
        ),
        title: const Text(
          '读诵练习',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          // 进度指示
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentIndex + 1}/${widget.sentences.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case ReadingState.idle:
        return _buildIdleView();
      case ReadingState.initializing:
        return _buildInitializingView();
      case ReadingState.listening:
      case ReadingState.switching:
        return _buildReadingView();
      case ReadingState.completed:
        return _buildCompletedView();
      case ReadingState.error:
        return _buildErrorView();
      default:
        return const Center(child: CircularProgressIndicator());
    }
  }

  /// 初始化视图
  Widget _buildInitializingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: Colors.amber),
        const SizedBox(height: 24),
        Text(
          _initMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ],
    );
  }

  /// 空闲视图 - 准备开始
  Widget _buildIdleView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.mic_none, color: Colors.amber, size: 80),
        const SizedBox(height: 24),
        const Text(
          '准备好了吗？',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          '共 ${widget.sentences.length} 句需要读诵',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          '使用离线语音识别（无需网络）',
          style: TextStyle(color: Colors.green, fontSize: 14),
        ),
        const SizedBox(height: 48),
        ElevatedButton.icon(
          onPressed: _startReading,
          icon: const Icon(Icons.play_arrow),
          label: const Text('开始读诵'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  /// 读诵视图
  Widget _buildReadingView() {
    final currentSentence = widget.sentences[_currentIndex];
    final isCompleting = _state == ReadingState.switching;
    
    return Column(
      children: [
        // 进度条
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / widget.sentences.length,
              minHeight: 8,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
        ),
        
        // 当前句子
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxHeight: 400),
                decoration: BoxDecoration(
                  color: isCompleting 
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isCompleting 
                        ? Colors.green.withValues(alpha: 0.5)
                        : Colors.amber.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCompleting)
                        const Icon(Icons.check_circle, color: Colors.green, size: 40),
                      if (!isCompleting) ...[
                        AnimatedBuilder(
                          animation: _pulseAnimation!,
                          builder: (context, child) => Transform.scale(
                            scale: _pulseAnimation!.value,
                            child: const Icon(Icons.mic, color: Colors.red, size: 40),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '请朗读以下经文',
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        currentSentence,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isCompleting ? Colors.green : Colors.amber,
                          height: 1.5,
                        ),
                      ),
                      if (_recognizedText.isNotEmpty && !isCompleting) ...[
                        const SizedBox(height: 24),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 12),
                        const Text(
                          '识别到:',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _recognizedText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // 底部按钮
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 跳过按钮
              OutlinedButton.icon(
                onPressed: _state == ReadingState.listening ? _skipCurrentSentence : null,
                icon: const Icon(Icons.skip_next, color: Colors.white54),
                label: const Text('跳过', style: TextStyle(color: Colors.white54)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 完成视图
  Widget _buildCompletedView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.celebration, color: Colors.amber, size: 80),
          SizedBox(height: 24),
          Text(
            '太棒了！',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            '读诵完成',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    );
  }

  /// 错误视图
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 80),
            const SizedBox(height: 24),
            Text(
              _errorMessage ?? '发生错误',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _state = ReadingState.idle;
                  _errorMessage = null;
                });
                _initServices();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
