import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 音频时间戳标记
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

/// 音频合并服务
/// 
/// 跨平台实现：
/// - iOS/Android: 使用 FFmpeg（需要原生代码支持）
/// - macOS: 使用 afconvert 系统命令
/// - Windows: 使用纯 Dart WAV 处理
class AudioMergerService {
  static AudioMergerService? _instance;
  static AudioMergerService get instance => _instance ??= AudioMergerService._();
  
  AudioMergerService._();
  
  bool get _isMacOS => !kIsWeb && Platform.isMacOS;
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get _isWindows => !kIsWeb && Platform.isWindows;

  /// 合并 PCM 文件并嵌入字幕轨道
  Future<String?> mergeWithSubtitle({
    required List<String> pcmPaths,
    required List<String> sentences,
    required List<AudioMarker> markers,
  }) async {
    if (pcmPaths.isEmpty || sentences.isEmpty || markers.isEmpty) {
      debugPrint('[AudioMerger] 参数为空');
      return null;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 1. 合并所有 PCM 文件
      final mergedPcmPath = '${tempDir.path}/merged_$timestamp.pcm';
      await _mergePcmFiles(pcmPaths, mergedPcmPath);
      
      // 2. 生成 SRT 字幕文件
      final srtPath = '${tempDir.path}/subtitle_$timestamp.srt';
      await _generateSrtFile(sentences, markers, srtPath);
      
      // 3. 转换 PCM 为音频格式
      String audioPath;
      
      if (_isWindows) {
        // Windows: 转为 WAV
        audioPath = '${tempDir.path}/audio_$timestamp.wav';
        await _pcmToWav(mergedPcmPath, audioPath);
        await _cleanupTempFiles([mergedPcmPath]);
        debugPrint('[AudioMerger] Windows 模式：返回 WAV 文件');
        return audioPath;
      } else if (_isMacOS) {
        // macOS: WAV -> M4A
        final wavPath = '${tempDir.path}/audio_$timestamp.wav';
        await _pcmToWav(mergedPcmPath, wavPath);
        
        audioPath = '${tempDir.path}/audio_$timestamp.m4a';
        final success = await _wavToM4aMacOS(wavPath, audioPath);
        
        if (!success) {
          debugPrint('[AudioMerger] macOS afconvert 失败，返回 WAV');
          await _cleanupTempFiles([mergedPcmPath]);
          return wavPath;
        }
        
        await _cleanupTempFiles([wavPath, mergedPcmPath]);
        return audioPath;
      } else {
        // iOS/Android: 需要 FFmpeg（原生代码支持）
        audioPath = '${tempDir.path}/audio_$timestamp.wav';
        await _pcmToWav(mergedPcmPath, audioPath);
        await _cleanupTempFiles([mergedPcmPath]);
        debugPrint('[AudioMerger] 移动端：返回 WAV 文件（FFmpeg 需要原生代码）');
        return audioPath;
      }
    } catch (e, stackTrace) {
      debugPrint('[AudioMerger] 合并失败: $e');
      debugPrint('[AudioMerger] 堆栈: $stackTrace');
      return null;
    }
  }

  Future<void> _mergePcmFiles(List<String> pcmPaths, String outputPath) async {
    final outputFile = File(outputPath);
    final sink = outputFile.openWrite();
    
    for (final path in pcmPaths) {
      final file = File(path);
      if (await file.exists()) {
        final data = await file.readAsBytes();
        sink.add(data);
      }
    }
    
    await sink.flush();
    await sink.close();
  }

  Future<void> _generateSrtFile(
    List<String> sentences,
    List<AudioMarker> markers,
    String outputPath,
  ) async {
    final buffer = StringBuffer();
    
    for (int i = 0; i < markers.length && i < sentences.length; i++) {
      final marker = markers[i];
      final sentence = sentences[i];
      
      buffer.writeln('${i + 1}');
      buffer.writeln('${_formatSrtTime(marker.startMs)} --> ${_formatSrtTime(marker.endMs)}');
      buffer.writeln(sentence);
      buffer.writeln();
    }
    
    final file = File(outputPath);
    await file.writeAsString(buffer.toString(), flush: true);
  }

  String _formatSrtTime(int ms) {
    final hours = ms ~/ 3600000;
    final minutes = (ms % 3600000) ~/ 60000;
    final seconds = (ms % 60000) ~/ 1000;
    final millis = ms % 1000;
    
    return '${hours.toString().padLeft(2, '0')}:'
           '${minutes.toString().padLeft(2, '0')}:'
           '${seconds.toString().padLeft(2, '0')},'
           '${millis.toString().padLeft(3, '0')}';
  }

  Future<void> _pcmToWav(String pcmPath, String wavPath) async {
    final pcmFile = File(pcmPath);
    final pcmData = await pcmFile.readAsBytes();
    
    const int sampleRate = 16000;
    const int bitsPerSample = 16;
    const int numChannels = 1;
    final int dataSize = pcmData.length;
    final int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final int blockAlign = numChannels * bitsPerSample ~/ 8;
    
    final wavHeader = <int>[
      0x52, 0x49, 0x46, 0x46,
      ...(_intToBytes(36 + dataSize, 4)),
      0x57, 0x41, 0x56, 0x45,
      0x66, 0x6D, 0x74, 0x20,
      0x10, 0x00, 0x00, 0x00,
      0x01, 0x00,
      ...(_intToBytes(numChannels, 2)),
      ...(_intToBytes(sampleRate, 4)),
      ...(_intToBytes(byteRate, 4)),
      ...(_intToBytes(blockAlign, 2)),
      ...(_intToBytes(bitsPerSample, 2)),
      0x64, 0x61, 0x74, 0x61,
      ...(_intToBytes(dataSize, 4)),
    ];
    
    final wavFile = File(wavPath);
    final sink = wavFile.openWrite();
    sink.add(wavHeader);
    sink.add(pcmData);
    await sink.flush();
    await sink.close();
  }
  
  List<int> _intToBytes(int value, int length) {
    final bytes = <int>[];
    for (int i = 0; i < length; i++) {
      bytes.add((value >> (i * 8)) & 0xFF);
    }
    return bytes;
  }

  Future<bool> _wavToM4aMacOS(String wavPath, String m4aPath) async {
    try {
      final result = await Process.run('afconvert', [
        '-f', 'm4af',
        '-d', 'aac',
        '-b', '128000',
        wavPath,
        m4aPath,
      ]);
      
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('[AudioMerger] macOS afconvert 异常: $e');
      return false;
    }
  }

  Future<void> _cleanupTempFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // 忽略清理失败
      }
    }
  }

  String generateSrtContent(List<String> sentences, List<AudioMarker> markers) {
    final buffer = StringBuffer();
    
    for (int i = 0; i < markers.length && i < sentences.length; i++) {
      final marker = markers[i];
      final sentence = sentences[i];
      
      buffer.writeln('${i + 1}');
      buffer.writeln('${_formatSrtTime(marker.startMs)} --> ${_formatSrtTime(marker.endMs)}');
      buffer.writeln(sentence);
      buffer.writeln();
    }
    
    return buffer.toString();
  }
}
