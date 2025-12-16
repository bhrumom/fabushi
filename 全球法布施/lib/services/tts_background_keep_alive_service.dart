import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// TTS 后台保活服务
/// 
/// 通过循环静音播放用户选择的经文来增强后台保活能力。
/// 利用 TTS 播放被系统视为"音频活动"的特性，减少应用被系统杀掉的概率。
/// 
/// 工作原理：
/// 1. 将经文内容分句
/// 2. 循环播放每个句子（静音或低音量）
/// 3. 在通知栏显示当前发送进度
/// 4. 配合前台服务一起工作，双重保障
class TtsBackgroundKeepAliveService {
  static final TtsBackgroundKeepAliveService _instance = TtsBackgroundKeepAliveService._internal();
  factory TtsBackgroundKeepAliveService() => _instance;
  TtsBackgroundKeepAliveService._internal();

  FlutterTts? _tts;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = true;  // 默认静音
  
  // 经文内容
  String _scriptureName = '';
  List<String> _sentences = [];
  int _currentSentenceIndex = 0;
  
  // 发送进度
  int _sentCount = 0;
  int _totalCount = 0;
  String _currentCountry = '';
  int _loopCount = 0;
  
  // 回调
  VoidCallback? _onComplete;
  
  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;

  /// 初始化 TTS 引擎
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _tts = FlutterTts();
      
      // 设置语言为中文
      await _tts!.setLanguage('zh-CN');
      
      // 设置语速（稍慢，让播放时间更长）
      await _tts!.setSpeechRate(0.8);
      
      // 设置音量（静音模式）
      await _tts!.setVolume(_isMuted ? 0.0 : 0.1);
      
      // 设置音调
      await _tts!.setPitch(1.0);
      
      // 等待每句话播放完成
      await _tts!.awaitSpeakCompletion(true);
      
      // 设置完成回调
      _tts!.setCompletionHandler(() {
        _onSentenceComplete();
      });
      
      // 设置错误回调
      _tts!.setErrorHandler((msg) {
        debugPrint('🔇 TTS保活 错误: $msg');
        // 发生错误时尝试继续下一句
        _onSentenceComplete();
      });
      
      _isInitialized = true;
      debugPrint('✅ TTS保活服务已初始化');
    } catch (e) {
      debugPrint('❌ TTS保活服务初始化失败: $e');
    }
  }

  /// 开始 TTS 保活
  /// 
  /// [scriptureName] - 经文名称（用于通知栏显示）
  /// [content] - 经文内容（将被分句循环播放）
  Future<void> start({
    required String scriptureName,
    required String content,
    int totalCountries = 0,
  }) async {
    if (_isPlaying) {
      debugPrint('⚠️ TTS保活已在运行中');
      return;
    }
    
    if (!_isInitialized) {
      await initialize();
    }
    
    if (content.isEmpty) {
      debugPrint('⚠️ 经文内容为空，无法启动TTS保活');
      return;
    }
    
    _scriptureName = scriptureName;
    _totalCount = totalCountries;
    _sentCount = 0;
    _loopCount = 0;
    _currentCountry = '';
    
    // 解析经文内容为句子
    _parseContent(content);
    
    if (_sentences.isEmpty) {
      debugPrint('⚠️ 无法解析经文内容');
      return;
    }
    
    _isPlaying = true;
    _currentSentenceIndex = 0;
    
    debugPrint('🔇 TTS保活启动: $_scriptureName (${_sentences.length}句)');
    
    // 开始播放第一句
    _playSentence(0);
  }

  /// 解析内容为句子列表
  void _parseContent(String content) {
    _sentences = [];
    
    // 使用标点分句
    final parts = content.split(RegExp(r'[，。！？、；：\n]+'));
    for (final p in parts) {
      final t = p.trim();
      if (t.isNotEmpty) {
        _sentences.add(t);
      }
    }
    
    debugPrint('🔇 TTS保活: 解析出 ${_sentences.length} 句');
  }

  /// 播放指定句子
  Future<void> _playSentence(int index) async {
    if (!_isPlaying || _sentences.isEmpty) return;
    
    // 循环索引
    _currentSentenceIndex = index % _sentences.length;
    
    // 如果是新一轮开始
    if (_currentSentenceIndex == 0 && index > 0) {
      _loopCount++;
      debugPrint('🔇 TTS保活: 开始第 ${_loopCount + 1} 轮');
    }
    
    final sentence = _sentences[_currentSentenceIndex];
    
    try {
      // 确保音量正确
      await _tts?.setVolume(_isMuted ? 0.0 : 0.1);
      
      // 播放句子
      await _tts?.speak(sentence);
    } catch (e) {
      debugPrint('🔇 TTS保活 播放错误: $e');
      // 延迟后重试下一句
      Future.delayed(const Duration(milliseconds: 500), () {
        _onSentenceComplete();
      });
    }
  }

  /// 句子播放完成回调
  void _onSentenceComplete() {
    if (!_isPlaying) return;
    
    // 短暂停顿后播放下一句
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_isPlaying) {
        _playSentence(_currentSentenceIndex + 1);
      }
    });
  }

  /// 更新发送进度（用于通知栏显示）
  void updateProgress({
    required int sentCount,
    required int totalCount,
    required String currentCountry,
    int? loopCount,
  }) {
    _sentCount = sentCount;
    _totalCount = totalCount;
    _currentCountry = currentCountry;
    if (loopCount != null) {
      _loopCount = loopCount;
    }
    
    // 可以在这里更新通知栏，但目前主要依赖 ForegroundServiceManager
    // 如果需要单独的通知，可以使用 audio_service
  }

  /// 停止 TTS 保活
  Future<void> stop() async {
    if (!_isPlaying) return;
    
    _isPlaying = false;
    
    try {
      await _tts?.stop();
      debugPrint('🔇 TTS保活已停止');
    } catch (e) {
      debugPrint('❌ 停止TTS保活失败: $e');
    }
    
    _sentences = [];
    _currentSentenceIndex = 0;
    _scriptureName = '';
  }

  /// 设置静音状态
  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    
    try {
      await _tts?.setVolume(muted ? 0.0 : 0.1);
      debugPrint('🔇 TTS保活静音: $muted');
    } catch (e) {
      debugPrint('❌ 设置静音失败: $e');
    }
  }

  /// 切换静音状态
  Future<void> toggleMute() async {
    await setMuted(!_isMuted);
  }

  /// 释放资源
  void dispose() {
    stop();
    _tts?.stop();
    _tts = null;
    _isInitialized = false;
  }
  
  /// 获取当前状态信息
  String get statusInfo {
    if (!_isPlaying) return '未运行';
    
    final muteStatus = _isMuted ? '(静音)' : '(有声)';
    return '$_scriptureName $muteStatus - 句${_currentSentenceIndex + 1}/${_sentences.length}';
  }
}
