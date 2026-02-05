import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/local_work_model.dart';
import '../services/audio_stream_service.dart';
import '../features/video_feed/presentation/view/widgets/video_feed_view_text_content.dart';
import '../providers/video_feed_visibility_notifier.dart';
import '../providers/tts_mute_notifier.dart';

/// 作品全屏播放页面 - 与法流视频风格一致
class WorkPlayerScreen extends StatefulWidget {
  final LocalWorkModel work;
  
  const WorkPlayerScreen({
    required this.work,
    super.key,
  });

  @override
  State<WorkPlayerScreen> createState() => _WorkPlayerScreenState();
}

class _WorkPlayerScreenState extends State<WorkPlayerScreen> {
  bool _isPlaying = false;
  bool _audioExists = false;
  String? _textContent;
  
  @override
  void initState() {
    super.initState();
    _initPlayer();
  }
  
  Future<void> _initPlayer() async {
    // 检查音频文件是否存在
    final file = File(widget.work.filePath);
    _audioExists = await file.exists();
    
    // 尝试读取文本内容（从contentId获取原始经文）
    // 这里暂时使用作品标题作为显示内容
    _textContent = widget.work.title;
    
    if (mounted) {
      setState(() {});
      if (_audioExists) {
        _playAudio();
      }
    }
  }
  
  Future<void> _playAudio() async {
    if (!_audioExists) return;
    
    await AudioStreamService.instance.playAudio(widget.work.filePath);
    if (mounted) {
      setState(() {
        _isPlaying = true;
      });
    }
  }
  
  Future<void> _stopAudio() async {
    await AudioStreamService.instance.stopPlayer();
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }
  
  void _togglePlayPause() {
    if (_isPlaying) {
      _stopAudio();
    } else {
      _playAudio();
    }
  }
  
  String _formatDuration(int ms) {
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  void dispose() {
    _stopAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 隐藏状态栏，全屏沉浸式体验
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VideoFeedVisibilityNotifier()..setVisible(true)),
        ChangeNotifierProvider(create: (_) => TtsMuteNotifier()..setMuted(true)), // 静音TTS，只播放录音
      ],
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 背景渐变
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                    Color(0xFF0F0F23),
                  ],
                ),
              ),
            ),
            
            // 文本内容区域 - 使用文本视频组件
            if (_textContent != null && _textContent!.isNotEmpty)
              Positioned.fill(
                child: VideoFeedViewTextContent(
                  textContent: _textContent!,
                  isVisible: true,
                ),
              )
            else
              // 无内容时显示作品标题
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    widget.work.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      height: 1.8,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            
            // 顶部返回按钮
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                onPressed: () {
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                  Navigator.of(context).pop();
                },
              ),
            ),
            
            // 底部信息栏
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(context).padding.bottom + 20,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black87,
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题
                    Text(
                      widget.work.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // 时长和播放按钮
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(widget.work.durationMs),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        
                        // 播放/暂停按钮
                        if (_audioExists)
                          GestureDetector(
                            onTap: _togglePlayPause,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          )
                        else
                          const Text(
                            '音频不可用',
                            style: TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
