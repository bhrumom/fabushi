import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// 条件编译：仅在移动端使用 ffmpeg_kit
import 'audio_merger_service_mobile.dart'
    if (dart.library.html) 'audio_merger_service_stub.dart'
    as platform;

/// 音频时间戳标记（用于字幕同步）
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
/// - iOS/Android: 使用 FFmpeg
/// - macOS: 使用 afconvert 系统命令 + 纯 Dart
/// - Windows: 使用纯 Dart WAV 处理
class AudioMergerService {
  static AudioMergerService? _instance;
  static AudioMergerService get instance => _instance ??= AudioMergerService._();
  
  AudioMergerService._();
  
  /// 是否是 macOS 平台
  bool get _isMacOS => !kIsWeb && Platform.isMacOS;
  
  /// 是否是移动端（支持 FFmpeg）
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  
  /// 是否是 Windows 平台
  bool get _isWindows => !kIsWeb && Platform.isWindows;

  /// 合并 PCM 文件并嵌入字幕轨道，输出 M4A
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
      
      // 3. 转换 PCM 为 音频格式
      String? audioPath;
      if (_isWindows) {
        // Windows: 转为 WAV（无需外部工具）
        audioPath = '${tempDir.path}/audio_$timestamp.wav';
        await _pcmToWav(mergedPcmPath, audioPath);
        await _cleanupTempFiles([mergedPcmPath]);
        debugPrint('[AudioMerger] Windows 模式：返回 WAV 文件');
        return audioPath;
      } else if (_isMacOS) {
        // macOS: 先转 WAV，再用 afconvert 转 M4A
        final wavPath = '${tempDir.path}/audio_$timestamp.wav';
        await _pcmToWav(mergedPcmPath, wavPath);
        
        audioPath = '${tempDir.path}/audio_$timestamp.m4a';
        final success = await _wavToM4aMacOS(wavPath, audioPath);
        
        if (!success) {
          // 如果转换失败，返回 WAV 文件
          debugPrint('[AudioMerger] macOS afconvert 失败，返回 WAV');
          await _cleanupTempFiles([mergedPcmPath]);
          return wavPath;
        }
        
        await _cleanupTempFiles([wavPath]);
      } else {
        // iOS/Android: 使用 FFmpeg
        audioPath = '${tempDir.path}/audio_$timestamp.m4a';
        final success = await platform.pcmToAacFFmpeg(mergedPcmPath, audioPath);
        if (!success) {
          debugPrint('[AudioMerger] FFmpeg PCM -> AAC 失败');
          return null;
        }
      }
      
      // 4. 尝试嵌入字幕轨道（仅 FFmpeg 支持）
      final outputPath = '${tempDir.path}/reading_$timestamp.m4a';
      bool embedSuccess = false;
      
      if (_isMobile) {
        embedSuccess = await platform.embedSubtitleFFmpeg(audioPath!, srtPath, outputPath);
      }
      
      if (embedSuccess) {
        debugPrint('[AudioMerger] 成功生成带字幕的音频: $outputPath');
        await _cleanupTempFiles([mergedPcmPath, srtPath, audioPath!]);
        return outputPath;
      } else {
        // macOS/Windows 或嵌入失败，返回纯音频 + 独立字幕文件
        debugPrint('[AudioMerger] 返回纯音频（字幕保存在独立文件）');
        await _cleanupTempFiles([mergedPcmPath]);
        return audioPath;
      }
    } catch (e, stackTrace) {
      debugPrint('[AudioMerger] 合并失败: $e');
      debugPrint('[AudioMerger] 堆栈: $stackTrace');
      return null;
    }
  }

  /// 合并多个 PCM 文件
  Future<void> _mergePcmFiles(List<String> pcmPaths, String outputPath) async {
    final outputFile = File(outputPath);
    final sink = outputFile.openWrite();
    
    for (final path in pcmPaths) {
      final file = File(path);
      if (await file.exists()) {
        final data = await file.readAsBytes();
        sink.add(data);
        debugPrint('[AudioMerger] 已合并: $path (${data.length} bytes)');
      }
    }
    
    await sink.flush();
    await sink.close();
    
    final mergedSize = await outputFile.length();
    debugPrint('[AudioMerger] 合并完成: $outputPath ($mergedSize bytes)');
  }

  /// 生成 SRT 字幕文件
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
    
    debugPrint('[AudioMerger] 生成字幕: $outputPath');
  }

  /// 格式化 SRT 时间戳
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

  // =====================================================
  // 纯 Dart 方法（所有平台可用）
  // =====================================================

  /// PCM 转 WAV（纯 Dart 实现）
  /// 
  /// 为 PCM 数据添加 WAV 文件头
  Future<void> _pcmToWav(String pcmPath, String wavPath) async {
    final pcmFile = File(pcmPath);
    final pcmData = await pcmFile.readAsBytes();
    
    // WAV 文件头参数
    const int sampleRate = 16000;
    const int bitsPerSample = 16;
    const int numChannels = 1;
    final int dataSize = pcmData.length;
    final int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final int blockAlign = numChannels * bitsPerSample ~/ 8;
    
    // 构建 WAV 文件头 (44 bytes)
    final wavHeader = <int>[
      // RIFF header
      0x52, 0x49, 0x46, 0x46, // "RIFF"
      ...(_intToBytes(36 + dataSize, 4)), // File size - 8
      0x57, 0x41, 0x56, 0x45, // "WAVE"
      
      // fmt chunk
      0x66, 0x6D, 0x74, 0x20, // "fmt "
      0x10, 0x00, 0x00, 0x00, // Chunk size (16)
      0x01, 0x00, // Audio format (1 = PCM)
      ...(_intToBytes(numChannels, 2)), // Number of channels
      ...(_intToBytes(sampleRate, 4)), // Sample rate
      ...(_intToBytes(byteRate, 4)), // Byte rate
      ...(_intToBytes(blockAlign, 2)), // Block align
      ...(_intToBytes(bitsPerSample, 2)), // Bits per sample
      
      // data chunk
      0x64, 0x61, 0x74, 0x61, // "data"
      ...(_intToBytes(dataSize, 4)), // Data size
    ];
    
    // 写入 WAV 文件
    final wavFile = File(wavPath);
    final sink = wavFile.openWrite();
    sink.add(wavHeader);
    sink.add(pcmData);
    await sink.flush();
    await sink.close();
    
    debugPrint('[AudioMerger] PCM -> WAV 完成: $wavPath');
  }
  
  /// 整数转字节数组（小端序）
  List<int> _intToBytes(int value, int length) {
    final bytes = <int>[];
    for (int i = 0; i < length; i++) {
      bytes.add((value >> (i * 8)) & 0xFF);
    }
    return bytes;
  }

  /// WAV 转 M4A（macOS afconvert 命令）
  Future<bool> _wavToM4aMacOS(String wavPath, String m4aPath) async {
    try {
      // 使用 macOS 自带的 afconvert 命令
      // -f m4af: 输出 M4A 格式
      // -d aac: 使用 AAC 编码
      // -b 128000: 比特率 128kbps
      final result = await Process.run('afconvert', [
        '-f', 'm4af',
        '-d', 'aac',
        '-b', '128000',
        wavPath,
        m4aPath,
      ]);
      
      if (result.exitCode == 0) {
        debugPrint('[AudioMerger] macOS afconvert 成功: $m4aPath');
        return true;
      } else {
        debugPrint('[AudioMerger] macOS afconvert 失败: ${result.stderr}');
        return false;
      }
    } catch (e) {
      debugPrint('[AudioMerger] macOS afconvert 异常: $e');
      return false;
    }
  }

  /// 清理临时文件
  Future<void> _cleanupTempFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('[AudioMerger] 清理失败: $path - $e');
      }
    }
  }

  /// 获取 SRT 字幕内容
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
