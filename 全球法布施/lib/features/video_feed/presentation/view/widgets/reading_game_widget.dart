import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../../services/audio_stream_service.dart';
import '../../../../../services/audio_merger_service.dart';
import '../../../../../services/local_work_service.dart';
import '../../../../../models/local_work_model.dart';
import '../../../../../services/comment_service.dart';
import '../../../../../models/auth_model.dart';
import 'package:provider/provider.dart';

/// 读诵游戏状态
enum ReadingState {
  idle,          // 空闲，等待开始
  initializing,  // 正在初始化
  ready,         // 准备就绪，等待开始录音
  recording,     // 正在录音
  merging,       // 正在合并音频
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
/// 1. 逐句显示经文
/// 2. 用户手动录音每个句子
/// 3. 点击"下一句"切换
/// 4. 最后合并所有音频并嵌入字幕
class ReadingGameWidget extends StatefulWidget {
  const ReadingGameWidget({
    required this.sentences,
    required this.contentId,
    required this.contentTitle,
    this.onComplete,
    super.key,
  });

  /// 句子列表
  final List<String> sentences;
  
  /// 内容ID（用于评论关联）
  final String contentId;
  
  /// 内容标题（用于作品展示）
  final String contentTitle;
  
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
  
  /// 音频合并服务
  final AudioMergerService _mergerService = AudioMergerService.instance;
  
  /// 每个句子的 PCM 文件路径
  final List<String> _pcmPaths = [];
  
  /// 时间戳标记
  final List<AudioMarker> _markers = [];
  
  /// 当前句子开始时间（相对于总录音）
  int _currentSentenceStartMs = 0;
  
  /// 总录音时长（毫秒）
  int _totalRecordingMs = 0;
  
  /// 当前句子录音开始时间
  DateTime? _sentenceRecordStartTime;
  
  /// 错误信息
  String? _errorMessage;
  
  /// 初始化进度消息
  String _initMessage = '';
  
  /// 动画控制器
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initServices();
  }

  @override
  void dispose() {
    _stopRecording();
    _pulseController?.dispose();
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

  /// 开始录音（第一句）
  Future<void> _startReading() async {
    setState(() {
      _state = ReadingState.ready;
      _currentIndex = 0;
      _pcmPaths.clear();
      _markers.clear();
      _totalRecordingMs = 0;
    });
    
    // 自动开始第一句的录音
    await _startSentenceRecording();
  }

  /// 开始当前句子的录音
  Future<void> _startSentenceRecording() async {
    try {
      // 生成当前句子的 PCM 文件路径
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final pcmPath = '${tempDir.path}/sentence_${_currentIndex}_$timestamp.pcm';
      
      // 开始录音
      final stream = await _audioService.startRecording(saveToFile: true);
      if (stream == null) {
        _showError('开始录音失败');
        return;
      }
      
      // 保存当前录音路径
      _pcmPaths.add(_audioService.currentRecordingPath ?? pcmPath);
      
      _currentSentenceStartMs = _totalRecordingMs;
      _sentenceRecordStartTime = DateTime.now();
      
      setState(() {
        _state = ReadingState.recording;
      });
      
      HapticFeedback.lightImpact();
      debugPrint('[ReadingGame] 开始录音第 ${_currentIndex + 1} 句: "${widget.sentences[_currentIndex]}"');
    } catch (e) {
      debugPrint('[ReadingGame] 开始录音异常: $e');
      _showError('开始录音失败: $e');
    }
  }

  /// 切换到下一句
  Future<void> _nextSentence() async {
    if (_state != ReadingState.recording) return;
    
    HapticFeedback.mediumImpact();
    
    // 停止当前录音
    await _audioService.stopRecording();
    
    // 计算当前句子的时长
    final sentenceDurationMs = _sentenceRecordStartTime != null
        ? DateTime.now().difference(_sentenceRecordStartTime!).inMilliseconds
        : 0;
    
    // 记录时间戳标记
    _markers.add(AudioMarker(
      sentenceIndex: _currentIndex,
      startMs: _currentSentenceStartMs,
      endMs: _currentSentenceStartMs + sentenceDurationMs,
    ));
    
    _totalRecordingMs = _currentSentenceStartMs + sentenceDurationMs;
    
    debugPrint('[ReadingGame] 第 ${_currentIndex + 1} 句完成，时长: ${sentenceDurationMs}ms');
    
    // 切换到下一句
    _currentIndex++;
    
    if (_currentIndex >= widget.sentences.length) {
      // 全部完成，合并音频
      await _completeReading();
    } else {
      // 继续下一句
      setState(() {
        _state = ReadingState.ready;
      });
      
      // 延迟后开始下一句录音
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await _startSentenceRecording();
      }
    }
  }

  /// 完成读诵
  Future<void> _completeReading() async {
    setState(() {
      _state = ReadingState.merging;
    });
    
    try {
      // 合并音频并嵌入字幕
      final outputPath = await _mergerService.mergeWithSubtitle(
        pcmPaths: _pcmPaths,
        sentences: widget.sentences,
        markers: _markers,
      );
      
      // 清理临时 PCM 文件
      for (final path in _pcmPaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('[ReadingGame] 清理临时文件失败: $e');
        }
      }
      
      setState(() {
        _state = ReadingState.completed;
      });
      
      HapticFeedback.heavyImpact();
      
      // 延迟后显示结果
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        final totalDuration = Duration(milliseconds: _totalRecordingMs);
        final result = ReadingResult(
          audioPath: outputPath,
          markers: _markers,
          totalDuration: totalDuration,
        );
        
        _showCompletionDialog(result);
      }
    } catch (e) {
      debugPrint('[ReadingGame] 完成读诵异常: $e');
      _showError('合并音频失败: $e');
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
                '录音已保存（含字幕轨道） ✓',
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
            onPressed: () => _handlePublish(context, result),
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

  Future<void> _handlePublish(BuildContext dialogContext, ReadingResult result) async {
    if (result.audioPath == null) return;
    
    // Check auth
    final authModel = Provider.of<AuthModel>(context, listen: false);
    if (authModel.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录后发布')),
      );
      return;
    }

    try {
      // 1. Save locally
      final work = LocalWorkModel.create(
        contentId: widget.contentId,
        title: widget.contentTitle,
        filePath: result.audioPath!,
        durationMs: result.totalDuration.inMilliseconds,
      );
      await LocalWorkService.instance.saveWork(work);
      
      // 2. Post comment with attachment
      final commentService = CommentService();
      await commentService.postComment(
        widget.contentId,
        '我在读诵练习中完成了《${widget.contentTitle}》的录制，快来听听吧！',
        contentTitle: widget.contentTitle,
        attachmentPath: result.audioPath,
        attachmentType: 'audio',
      );
      
      if (mounted) {
        Navigator.of(dialogContext).pop(); // Close dialog
        Navigator.of(context).pop(); // Close game
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(content: Text('发布成功！已保存到"作品"和评论区')),
        );
      }
    } catch (e) {
      debugPrint('Publish failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发布失败: $e')),
        );
      }
    }
  }


  /// 格式化时长
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes 分 $seconds 秒';
  }

  /// 停止录音
  Future<void> _stopRecording() async {
    try {
      await _audioService.stopRecording();
    } catch (e) {
      debugPrint('[ReadingGame] 停止录音异常: $e');
    }
  }

  /// 显示错误
  void _showError(String message) {
    setState(() {
      _state = ReadingState.error;
      _errorMessage = message;
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
          onPressed: () async {
            final navigator = Navigator.of(context);
            await _stopRecording();
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
      case ReadingState.ready:
      case ReadingState.recording:
        return _buildReadingView();
      case ReadingState.merging:
        return _buildMergingView();
      case ReadingState.completed:
        return _buildCompletedView();
      case ReadingState.error:
        return _buildErrorView();
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
          '朗读完每句后点击"下一句"',
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
    final isRecording = _state == ReadingState.recording;
    final isLastSentence = _currentIndex == widget.sentences.length - 1;
    
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
                  color: isRecording 
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isRecording 
                        ? Colors.red.withValues(alpha: 0.5)
                        : Colors.amber.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRecording) ...[
                        AnimatedBuilder(
                          animation: _pulseAnimation!,
                          builder: (context, child) => Transform.scale(
                            scale: _pulseAnimation!.value,
                            child: const Icon(Icons.mic, color: Colors.red, size: 40),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '正在录音...',
                          style: TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ] else ...[
                        const Icon(Icons.mic_off, color: Colors.white38, size: 40),
                        const SizedBox(height: 8),
                        const Text(
                          '准备录音',
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
                          color: isRecording ? Colors.white : Colors.amber,
                          height: 1.5,
                        ),
                      ),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 下一句/完成按钮
              ElevatedButton.icon(
                onPressed: isRecording ? _nextSentence : null,
                icon: Icon(isLastSentence ? Icons.check : Icons.skip_next),
                label: Text(isLastSentence ? '完成录音' : '下一句'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLastSentence ? Colors.green : Colors.amber,
                  foregroundColor: isLastSentence ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 合并中视图
  Widget _buildMergingView() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: Colors.amber),
        SizedBox(height: 24),
        Text(
          '正在合并音频并生成字幕...',
          style: TextStyle(color: Colors.white70, fontSize: 16),
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
