import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';

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
/// 使用 FFmpeg 实现：
/// 1. 合并多个 PCM 音频文件
/// 2. 生成 SRT 字幕文件
/// 3. 将音频和字幕嵌入到 M4A 容器（体积最小）
class AudioMergerService {
  static AudioMergerService? _instance;
  static AudioMergerService get instance => _instance ??= AudioMergerService._();
  
  AudioMergerService._();

  /// 合并 PCM 文件并嵌入字幕轨道，输出 M4A
  /// 
  /// [pcmPaths] PCM 音频文件路径列表（按顺序）
  /// [sentences] 对应的句子文本列表
  /// [markers] 时间戳标记列表
  /// 
  /// 返回带字幕轨的 M4A 文件路径
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
      
      // 3. 转换 PCM 为 AAC 并输出 M4A
      final audioPath = '${tempDir.path}/audio_$timestamp.m4a';
      final pcmToAacSuccess = await _pcmToAac(mergedPcmPath, audioPath);
      if (!pcmToAacSuccess) {
        debugPrint('[AudioMerger] PCM 转 AAC 失败');
        return null;
      }
      
      // 4. 嵌入字幕轨道
      final outputPath = '${tempDir.path}/reading_$timestamp.m4a';
      final embedSuccess = await _embedSubtitle(audioPath, srtPath, outputPath);
      
      if (embedSuccess) {
        debugPrint('[AudioMerger] 成功生成带字幕的音频: $outputPath');
        
        // 清理临时文件
        await _cleanupTempFiles([mergedPcmPath, srtPath, audioPath]);
        
        return outputPath;
      } else {
        // 如果嵌入字幕失败，至少返回纯音频
        debugPrint('[AudioMerger] 嵌入字幕失败，返回纯音频');
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
      
      // SRT 序号（从 1 开始）
      buffer.writeln('${i + 1}');
      
      // 时间戳: HH:MM:SS,mmm --> HH:MM:SS,mmm
      buffer.writeln('${_formatSrtTime(marker.startMs)} --> ${_formatSrtTime(marker.endMs)}');
      
      // 字幕文本
      buffer.writeln(sentence);
      
      // 空行分隔
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

  /// PCM 转 AAC (M4A 容器)
  /// 
  /// 输入: 16kHz, 16-bit, mono PCM
  /// 输出: AAC 编码的 M4A
  Future<bool> _pcmToAac(String pcmPath, String outputPath) async {
    // FFmpeg 命令：将 PCM 转换为 AAC
    // -f s16le: 输入格式为 16-bit little-endian signed integer
    // -ar 16000: 采样率 16kHz
    // -ac 1: 单声道
    // -c:a aac: 使用 AAC 编码器
    // -b:a 128k: 比特率 128kbps
    final command = '-y -f s16le -ar 16000 -ac 1 -i "$pcmPath" '
                    '-c:a aac -b:a 128k "$outputPath"';
    
    debugPrint('[AudioMerger] 执行 FFmpeg: $command');
    
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    
    if (ReturnCode.isSuccess(returnCode)) {
      debugPrint('[AudioMerger] PCM -> AAC 成功');
      return true;
    } else {
      final logs = await session.getAllLogsAsString();
      debugPrint('[AudioMerger] PCM -> AAC 失败: $logs');
      return false;
    }
  }

  /// 嵌入字幕轨道到 M4A
  Future<bool> _embedSubtitle(String audioPath, String srtPath, String outputPath) async {
    // FFmpeg 命令：将 SRT 字幕嵌入到 M4A 容器
    // -c copy: 复制音频流（不重新编码）
    // -c:s mov_text: 将字幕编码为 mov_text 格式（M4A/MP4 支持）
    final command = '-y -i "$audioPath" -i "$srtPath" '
                    '-c copy -c:s mov_text "$outputPath"';
    
    debugPrint('[AudioMerger] 执行 FFmpeg: $command');
    
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    
    if (ReturnCode.isSuccess(returnCode)) {
      debugPrint('[AudioMerger] 嵌入字幕成功');
      return true;
    } else {
      final logs = await session.getAllLogsAsString();
      debugPrint('[AudioMerger] 嵌入字幕失败: $logs');
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

  /// 获取 SRT 字幕内容（用于调试或导出）
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
