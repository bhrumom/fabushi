import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';

/// PCM 转 AAC (FFmpeg) - 仅移动端使用
Future<bool> pcmToAacFFmpeg(String pcmPath, String outputPath) async {
  final command = '-y -f s16le -ar 16000 -ac 1 -i "$pcmPath" '
                  '-af "aresample=44100,lowpass=f=7500,dynaudnorm=f=150:g=15,afftdn=nf=-25" '
                  '-c:a aac -profile:a aac_low -b:a 128k "$outputPath"';
  
  debugPrint('[AudioMerger] 执行 FFmpeg: $command');
  
  final session = await FFmpegKit.execute(command);
  final returnCode = await session.getReturnCode();
  
  if (ReturnCode.isSuccess(returnCode)) {
    debugPrint('[AudioMerger] FFmpeg PCM -> AAC 成功');
    return true;
  } else {
    final logs = await session.getAllLogsAsString();
    debugPrint('[AudioMerger] FFmpeg PCM -> AAC 失败: $logs');
    return false;
  }
}

/// 嵌入字幕轨道 (FFmpeg) - 仅移动端使用
Future<bool> embedSubtitleFFmpeg(String audioPath, String srtPath, String outputPath) async {
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
