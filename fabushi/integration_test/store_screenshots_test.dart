import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/main.dart' as app;
import 'package:global_dharma_sharing/services/eula_service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Store screenshots', () {
    testWidgets('captures core app screens for store listings', (tester) async {
      await _prepareStoreScreenshotState();

      await app.main();
      await _waitForFirstScreen(tester);

      await _capture(tester, binding, 'screenshot-home');

      await _openTab(tester, const ['禅室', 'Zen Room']);
      await _capture(tester, binding, 'screenshot-meditation-room');

      await _openTab(tester, const ['我的', 'Profile']);
      await _capture(tester, binding, 'screenshot-profile');
    });
  });
}

Future<void> _prepareStoreScreenshotState() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('localePreference', 'zh-Hans');
  await prefs.setBool('darkMode', true);
  await prefs.setBool('notificationsEnabled', false);
  await EulaService.accept();
}

Future<void> _waitForFirstScreen(WidgetTester tester) async {
  for (var i = 0; i < 60; i += 1) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.text('首页').evaluate().isNotEmpty ||
        find.text('Home').evaluate().isNotEmpty) {
      await tester.pump(const Duration(seconds: 2));
      return;
    }
  }

  fail('Timed out waiting for the main navigation screen.');
}

Future<void> _openTab(WidgetTester tester, List<String> labels) async {
  Finder? finder;
  for (final label in labels) {
    final candidate = find.text(label);
    if (candidate.evaluate().isNotEmpty) {
      finder = candidate;
      break;
    }
  }

  if (finder == null) {
    fail('Could not find navigation tab with labels: ${labels.join(', ')}');
  }

  await tester.tap(finder.last);
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _capture(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  if (Platform.isAndroid) {
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
  }

  await binding.takeScreenshot(name);

  if (Platform.isAndroid) {
    await binding.revertFlutterImage();
    await tester.pump();
  }
}
