import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String?> saveDharmaPublishScreenshot({
  required String platformName,
  required String label,
  required Uint8List bytes,
}) async {
  if (bytes.isEmpty) return null;
  final dir = await getApplicationDocumentsDirectory();
  final screenshotsDir = Directory('${dir.path}/dharma_publish_screenshots');
  if (!await screenshotsDir.exists()) {
    await screenshotsDir.create(recursive: true);
  }
  final safeLabel = label
      .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .toLowerCase();
  final safePlatform = platformName
      .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .toLowerCase();
  final file = File(
    '${screenshotsDir.path}/${safePlatform}_${DateTime.now().millisecondsSinceEpoch}_$safeLabel.png',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
