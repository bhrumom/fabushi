/// Stub implementation for platforms that don't support ffmpeg_kit (Windows, macOS, Linux, Web)

Future<bool> pcmToAacFFmpeg(String pcmPath, String outputPath) async {
  // FFmpeg not supported on this platform
  return false;
}

Future<bool> embedSubtitleFFmpeg(String audioPath, String srtPath, String outputPath) async {
  // FFmpeg not supported on this platform
  return false;
}
