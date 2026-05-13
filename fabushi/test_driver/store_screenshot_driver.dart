import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outputDir =
      Platform.environment['STORE_SCREENSHOT_OUTPUT_DIR'] ??
      'build/store_screenshots/raw';
  final directory = Directory(outputDir);
  await directory.create(recursive: true);

  await integrationDriver(
    driver: await FlutterDriver.connect(),
    onScreenshot: (name, bytes, [args]) async {
      final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final file = File('${directory.path}/$safeName.png');
      await file.writeAsBytes(bytes);
      stderr.writeln('Saved store screenshot: ${file.path}');
      return true;
    },
  );
}
