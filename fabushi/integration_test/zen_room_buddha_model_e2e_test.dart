import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/main.dart' as app;
import 'package:global_dharma_sharing/services/asset_loader_service.dart';
import 'package:global_dharma_sharing/services/eula_service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Zen room Buddha model E2E', () {
    testWidgets('downloads and renders the Buddha .model in the Zen room', (
      tester,
    ) async {
      await _prepareZenRoomState();
      await AssetLoaderService.evictBuddhaModelCache();

      await app.main();
      await _waitForFirstScreen(tester);
      await _openZenRoomTab(tester);
      await _waitForBuddhaModelReady(tester);
    });
  });
}

Future<void> _prepareZenRoomState() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('localePreference', 'zh-Hans');
  await prefs.setBool('darkMode', true);
  await prefs.setBool('notificationsEnabled', false);
  await EulaService.accept();
}

Future<void> _waitForFirstScreen(WidgetTester tester) async {
  for (var i = 0; i < 90; i += 1) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.text('首页').evaluate().isNotEmpty ||
        find.text('Home').evaluate().isNotEmpty) {
      await tester.pump(const Duration(seconds: 1));
      return;
    }
  }

  fail('Timed out waiting for the main navigation screen.');
}

Future<void> _openZenRoomTab(WidgetTester tester) async {
  final finder = _findFirstText(const ['禅室', 'Zen Room']);
  if (finder == null) {
    fail('Could not find the Zen room navigation tab.');
  }

  await tester.tap(finder.last);
  await tester.pump(const Duration(seconds: 2));
}

Finder? _findFirstText(List<String> labels) {
  for (final label in labels) {
    final candidate = find.text(label);
    if (candidate.evaluate().isNotEmpty) {
      return candidate;
    }
  }
  return null;
}

Future<void> _waitForBuddhaModelReady(WidgetTester tester) async {
  final readyFinder = find.byKey(const ValueKey('buddha-model-ready'));
  final errorFinder = find.byKey(const ValueKey('buddha-model-error'));

  for (var i = 0; i < 360; i += 1) {
    await tester.pump(const Duration(seconds: 1));

    if (errorFinder.evaluate().isNotEmpty) {
      fail(
        'Buddha .model failed to load in the Zen room. '
        'Visible text: ${_visibleTextSnapshot(tester)}',
      );
    }

    if (readyFinder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(seconds: 1));
      return;
    }
  }

  fail(
    'Timed out waiting for the Buddha .model to download and render. '
    'Visible text: ${_visibleTextSnapshot(tester)}',
  );
}

String _visibleTextSnapshot(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .where((text) => text.trim().isNotEmpty)
      .take(40)
      .join(' | ');
}
