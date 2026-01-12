import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lpinyin/lpinyin.dart';
import '../../../../../services/audio_stream_service.dart';
import '../../../../../services/audio_merger_service.dart';
import '../../../../../services/local_work_service.dart';
import '../../../../../models/local_work_model.dart';
import '../../../../../services/comment_service.dart';
import '../../../../../models/auth_model.dart';
import '../../../../../services/sherpa_stt_service.dart';
import '../../../../../services/sentence_matching_service.dart';
import 'package:provider/provider.dart';
import 'video_feed_view_full_text_reader.dart';

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
  
  /// 语音识别服务
  final SherpaSTTService _sttService = SherpaSTTService.instance;
  
  /// 智能句子匹配服务
  final SentenceMatchingService _matchingService = SentenceMatchingService();
  
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
  
  /// 智能识别相关状态
  bool _isAutoModeEnabled = true;  // 是否启用自动模式
  double _matchProgress = 0.0;     // 当前句子的匹配进度
  String _recognizedText = '';     // 当前识别到的文本
  StreamSubscription<Uint8List>? _audioStreamSubscription;  // 音频流订阅
  
  /// K歌风格歌词滚动控制器
  late ScrollController _lyricsScrollController;
  
  /// 每行歌词的高度（用于计算滚动位置，增加高度以容纳拼音）
  static const double _lyricLineHeight = 100.0;

  @override
  void initState() {
    super.initState();
    _lyricsScrollController = ScrollController();
    _initAnimations();
    _initServices();
  }

  @override
  void dispose() {
    _stopRecording();
    _pulseController?.dispose();
    _lyricsScrollController.dispose();
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
      
      // 3. 初始化语音识别服务（用于智能识别）
      if (_isAutoModeEnabled) {
        setState(() {
          _initMessage = '正在初始化智能识别...';
        });
        debugPrint('[ReadingGame] 步骤3: 初始化语音识别服务...');
        _sttService.onProgress = (message) {
          if (mounted) {
            setState(() {
              _initMessage = message;
            });
          }
        };
        // 设置识别结果回调
        _sttService.onResult = _onSpeechResult;
        final sttSuccess = await _sttService.initialize();
        if (!sttSuccess) {
          debugPrint('[ReadingGame] 语音识别初始化失败，禁用自动模式');
          _isAutoModeEnabled = false;
        } else {
          // 加载匹配服务的阈值配置
          await _matchingService.loadConfig();
        }
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
  
  /// 语音识别结果回调
  void _onSpeechResult(String text, bool isFinal) {
    if (!mounted || _state != ReadingState.recording) return;
    
    final currentSentence = widget.sentences[_currentIndex];
    
    // 更新识别文本
    setState(() {
      _recognizedText = text;
      _matchProgress = _matchingService.getProgress(text, currentSentence);
    });
    
    // 检查是否应该自动切换
    if (_isAutoModeEnabled && 
        _matchingService.shouldAdvanceToNext(text, currentSentence, isFinal)) {
      debugPrint('[ReadingGame] 智能识别触发自动切换');
      _autoAdvanceToNext();
    }
  }
  
  /// 自动切换到下一句（由智能识别触发）
  Future<void> _autoAdvanceToNext() async {
    // 防止重复触发
    if (_state != ReadingState.recording) return;
    
    // 播放震动反馈
    HapticFeedback.heavyImpact();
    
    // 切换到下一句
    await _nextSentence();
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
      // 重置匹配服务状态
      _matchingService.reset();
      setState(() {
        _matchProgress = 0.0;
        _recognizedText = '';
      });
      
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
      
      // 如果启用自动模式，同时启动语音识别
      if (_isAutoModeEnabled && _sttService.isInitialized) {
        await _sttService.startRecognizing();
        // 监听音频流并发送给语音识别
        _audioStreamSubscription = stream.listen((audioData) {
          _sttService.processAudio(audioData);
        });
      }
      
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
    
    // 停止语音识别流订阅
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    
    // 停止语音识别
    if (_sttService.isRecognizing) {
      await _sttService.stopRecognizing();
    }
    
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
      
      // 滚动到新的当前句子
      _scrollToCurrentSentence();
      
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
    if (result.audioPath == null) {
      debugPrint('[ReadingGame] 错误: audioPath 为空');
      return;
    }
    
    debugPrint('[ReadingGame] === 开始发布 ===');
    debugPrint('[ReadingGame] audioPath: ${result.audioPath}');
    debugPrint('[ReadingGame] contentId: ${widget.contentId}');
    debugPrint('[ReadingGame] contentTitle: ${widget.contentTitle}');
    debugPrint('[ReadingGame] durationMs: ${result.totalDuration.inMilliseconds}');
    
    // Check auth
    final authModel = Provider.of<AuthModel>(context, listen: false);
    if (authModel.currentUser == null) {
      debugPrint('[ReadingGame] 错误: 用户未登录');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录后发布')),
      );
      return;
    }

    try {
      // 1. Save locally (音频保存在本地)
      debugPrint('[ReadingGame] 步骤1: 保存音频到本地数据库...');
      final work = LocalWorkModel.create(
        contentId: widget.contentId,
        title: widget.contentTitle,
        filePath: result.audioPath!,
        durationMs: result.totalDuration.inMilliseconds,
      );
      debugPrint('[ReadingGame] 创建 LocalWorkModel: id=${work.id}, title=${work.title}');
      
      await LocalWorkService.instance.saveWork(work);
      debugPrint('[ReadingGame] ✓ 本地音频保存成功');
      
      // 验证保存
      final savedWorks = await LocalWorkService.instance.getWorks();
      debugPrint('[ReadingGame] 当前本地作品数量: ${savedWorks.length}');
      
      // 2. Post comment to backend (评论文本上传后端，不传音频附件)
      debugPrint('[ReadingGame] 步骤2: 发布评论到后端（不含音频附件）...');
      final commentService = CommentService();
      final commentResult = await commentService.postComment(
        widget.contentId,
        '我在读诵练习中完成了《${widget.contentTitle}》的录制，快来听听吧！',
        contentTitle: widget.contentTitle,
        // 注：音频附件暂不上传，只保存在本地
      );
      
      if (commentResult['success'] == true) {
        debugPrint('[ReadingGame] ✓ 评论发布成功');
      } else {
        debugPrint('[ReadingGame] ⚠ 评论发布失败: ${commentResult['error']}');
      }
      
      if (mounted) {
        Navigator.of(dialogContext).pop(); // Close dialog
        Navigator.of(context).pop(); // Close game
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(content: Text('发布成功！已保存到"作品"和评论区')),
        );
        debugPrint('[ReadingGame] === 发布完成 ===');
      }
    } catch (e, stackTrace) {
      debugPrint('[ReadingGame] ❌ 发布失败: $e');
      debugPrint('[ReadingGame] 堆栈: $stackTrace');
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
      // 停止音频流订阅
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      
      // 停止语音识别
      if (_sttService.isRecognizing) {
        await _sttService.stopRecognizing();
      }
      
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
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, color: Colors.green, size: 18),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  '智能识别：念完后自动切换下一句',
                  style: TextStyle(color: Colors.green, fontSize: 14),
                ),
              ),
            ],
          ),
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

  /// 滚动到当前句子（K歌效果）
  void _scrollToCurrentSentence() {
    if (!_lyricsScrollController.hasClients) return;
    
    // 计算目标滚动位置：让当前句子居中
    final targetOffset = _currentIndex * _lyricLineHeight;
    
    _lyricsScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  /// 读诵视图 - K歌风格歌词滚动
  Widget _buildReadingView() {
    final isRecording = _state == ReadingState.recording;
    final isLastSentence = _currentIndex == widget.sentences.length - 1;
    
    return Column(
      children: [
        // 顶部状态栏
        _buildTopStatusBar(isRecording),
        
        // K歌风格歌词列表
        Expanded(
          child: _buildKaraokeLyrics(isRecording),
        ),
        
        // 底部按钮
        _buildBottomButton(isRecording, isLastSentence),
      ],
    );
  }
  
  /// 顶部状态栏
  Widget _buildTopStatusBar(bool isRecording) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          // 模式切换 + 进度
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 自动/手动模式切换
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isAutoModeEnabled = !_isAutoModeEnabled;
                  });
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isAutoModeEnabled 
                        ? Colors.green.withValues(alpha: 0.2) 
                        : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isAutoModeEnabled ? Colors.green : Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isAutoModeEnabled ? Icons.auto_awesome : Icons.touch_app,
                        size: 16,
                        color: _isAutoModeEnabled ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isAutoModeEnabled ? '智能识别' : '手动模式',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isAutoModeEnabled ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 录音状态指示
              if (isRecording)
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation!,
                      builder: (context, child) => Icon(
                        Icons.fiber_manual_record,
                        color: Colors.red,
                        size: 12 * _pulseAnimation!.value,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'REC',
                      style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              // 进度
              Text(
                '${_currentIndex + 1}/${widget.sentences.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / widget.sentences.length,
              minHeight: 4,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          // 智能识别进度
          if (_isAutoModeEnabled && isRecording) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _matchingService.getProgressHint(_matchProgress),
                  style: TextStyle(
                    fontSize: 11,
                    color: _matchProgress >= 0.50 ? Colors.green : Colors.white38,
                  ),
                ),
                Text(
                  '${(_matchProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: _matchProgress >= 0.50 ? Colors.green : Colors.white38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _matchProgress,
                minHeight: 3,
                backgroundColor: Colors.grey[900],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _matchProgress >= 0.70 ? Colors.green 
                      : _matchProgress >= 0.50 ? Colors.lightGreen 
                      : Colors.blue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  /// K歌风格歌词列表
  Widget _buildKaraokeLyrics(bool isRecording) {
    // 计算可见区域能容纳的行数
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.maxHeight;
        // 顶部留白，让当前句子居中
        final topPadding = (viewportHeight - _lyricLineHeight) / 2;
        final bottomPadding = topPadding;
        
        return GestureDetector(
          // 垂直拖动切换句子
          onVerticalDragEnd: (details) {
            if (_state != ReadingState.recording) return;
            
            final velocity = details.primaryVelocity ?? 0;
            // 上滑 (负速度) -> 下一句
            if (velocity < -200) {
              HapticFeedback.lightImpact();
              _nextSentence();
            }
            // 下滑 (正速度) -> 上一句
            else if (velocity > 200 && _currentIndex > 0) {
              HapticFeedback.lightImpact();
              _goToPreviousSentence();
            }
          },
          child: ShaderMask(
            // 顶部和底部渐变遮罩
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.15, 0.85, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ListView.builder(
              controller: _lyricsScrollController,
              physics: const NeverScrollableScrollPhysics(), // 禁止自由滚动，只响应手势
              padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
              itemCount: widget.sentences.length,
              itemBuilder: (context, index) {
                return _buildLyricLine(index, isRecording);
              },
            ),
          ),
        );
      },
    );
  }
  
  /// 切换到上一句
  Future<void> _goToPreviousSentence() async {
    if (_currentIndex <= 0) return;
    
    // 停止当前录音
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    if (_sttService.isRecognizing) {
      await _sttService.stopRecognizing();
    }
    await _audioService.stopRecording();
    
    // 移除最后一个 PCM 文件记录（如果有）
    if (_pcmPaths.isNotEmpty) {
      _pcmPaths.removeLast();
    }
    
    // 切换到上一句
    _currentIndex--;
    
    setState(() {
      _state = ReadingState.ready;
    });
    
    // 滚动到新位置
    _scrollToCurrentSentence();
    
    // 延迟后开始录音
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      await _startSentenceRecording();
    }
  }
  
  /// 构建单行歌词
  Widget _buildLyricLine(int index, bool isRecording) {
    final isCurrent = index == _currentIndex;
    final isPast = index < _currentIndex;
    final distance = (index - _currentIndex).abs();
    
    // 透明度：当前句子最亮，距离越远越淡
    double opacity;
    if (isCurrent) {
      opacity = 1.0;
    } else if (distance == 1) {
      opacity = 0.5;
    } else if (distance == 2) {
      opacity = 0.3;
    } else {
      opacity = 0.15;
    }
    
    // 字体大小：当前句子最大
    final fontSize = isCurrent ? 24.0 : 16.0;
    final pinyinFontSize = isCurrent ? 11.0 : 9.0;
    
    // 颜色
    Color textColor;
    Color pinyinColor;
    if (isCurrent) {
      if (isRecording && _matchProgress >= 0.50) {
        textColor = Colors.green;
        pinyinColor = Colors.green.withValues(alpha: 0.8);
      } else if (isRecording) {
        textColor = Colors.white;
        pinyinColor = const Color(0xFF88C0D0);
      } else {
        textColor = Colors.amber;
        pinyinColor = Colors.amber.withValues(alpha: 0.8);
      }
    } else if (isPast) {
      textColor = Colors.green.withValues(alpha: opacity * 0.8);
      pinyinColor = Colors.green.withValues(alpha: opacity * 0.5);
    } else {
      textColor = Colors.white.withValues(alpha: opacity);
      pinyinColor = Colors.white.withValues(alpha: opacity * 0.6);
    }
    
    // 当前句子需要更多空间容纳可能的多行换行
    final lineHeight = isCurrent ? _lyricLineHeight * 1.5 : _lyricLineHeight;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      constraints: BoxConstraints(
        minHeight: isCurrent ? _lyricLineHeight : _lyricLineHeight * 0.6,
        maxHeight: lineHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: isCurrent
          ? _buildSentenceWithPinyin(
              widget.sentences[index],
              fontSize: fontSize,
              pinyinFontSize: pinyinFontSize,
              textColor: textColor,
              pinyinColor: pinyinColor,
              fontWeight: FontWeight.bold,
            )
          : _buildSentenceWithPinyin(
              widget.sentences[index],
              fontSize: fontSize,
              pinyinFontSize: pinyinFontSize,
              textColor: textColor,
              pinyinColor: pinyinColor,
              fontWeight: FontWeight.normal,
            ),
    );
  }
  
  /// 构建带拼音的句子（复用阅读器的拼音逻辑）
  Widget _buildSentenceWithPinyin(
    String sentence, {
    required double fontSize,
    required double pinyinFontSize,
    required Color textColor,
    required Color pinyinColor,
    required FontWeight fontWeight,
  }) {
    final chars = _processSentenceToPinyin(sentence);
    
    // 使用 Wrap 自动换行，确保内容始终完整显示在屏幕内
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 2,  // 字符间距
      runSpacing: 4,  // 行间距
      children: chars.map((charData) {
        if (charData.type == CharType.chinese) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  charData.pinyin ?? '',
                  style: TextStyle(
                    fontSize: pinyinFontSize,
                    color: pinyinColor,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  charData.char,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: textColor,
                    fontWeight: fontWeight,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          );
        } else if (charData.type == CharType.punctuation) {
          return Padding(
            padding: EdgeInsets.only(top: pinyinFontSize + 4),
            child: Text(
              charData.char,
              style: TextStyle(
                fontSize: fontSize,
                color: textColor.withValues(alpha: 0.7),
                fontWeight: fontWeight,
              ),
            ),
          );
        } else if (charData.type == CharType.space) {
          return const SizedBox(width: 8);
        } else {
          return Padding(
            padding: EdgeInsets.only(top: pinyinFontSize + 4),
            child: Text(
              charData.char,
              style: TextStyle(
                fontSize: fontSize,
                color: textColor,
                fontWeight: fontWeight,
              ),
            ),
          );
        }
      }).toList(),
    );
  }
  
  /// 处理句子生成拼音数据（复用阅读器的逻辑）
  List<CharData> _processSentenceToPinyin(String sentence) {
    final chars = <CharData>[];
    final trie = PhraseTrie.instance;
    int i = 0;
    
    while (i < sentence.length) {
      final char = sentence[i];
      
      // 使用 Trie 树匹配词组
      final match = trie.matchLongest(sentence, i);
      
      if (match != null) {
        for (int j = 0; j < match.phrase.length; j++) {
          chars.add(CharData(match.phrase[j], match.pinyin[j], CharType.chinese));
        }
        i += match.phrase.length;
      } else if (_isChinese(char)) {
        final pinyin = BuddhistPinyinDictionary.singleCharOverride[char] ??
            PinyinHelper.getPinyin(char, separator: '', format: PinyinFormat.WITH_TONE_MARK);
        chars.add(CharData(char, pinyin, CharType.chinese));
        i++;
      } else if (char == ' ' || char == '\t') {
        chars.add(CharData(char, null, CharType.space));
        i++;
      } else if (_isPunctuation(char)) {
        chars.add(CharData(char, null, CharType.punctuation));
        i++;
      } else {
        chars.add(CharData(char, null, CharType.other));
        i++;
      }
    }
    
    return chars;
  }
  
  /// 判断是否为中文字符
  bool _isChinese(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 0x4E00 && code <= 0x9FFF) || (code >= 0x3400 && code <= 0x4DBF);
  }
  
  /// 判断是否为标点符号
  bool _isPunctuation(String char) {
    const punctuations = '，。！？、；：""''（）【】《》…—·．';
    return punctuations.contains(char);
  }
  
  /// 底部按钮
  Widget _buildBottomButton(bool isRecording, bool isLastSentence) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: isRecording ? _nextSentence : null,
            icon: Icon(isLastSentence ? Icons.check : Icons.skip_next),
            label: Text(isLastSentence ? '完成录音' : '下一句'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isLastSentence ? Colors.green : Colors.amber,
              foregroundColor: isLastSentence ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
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
