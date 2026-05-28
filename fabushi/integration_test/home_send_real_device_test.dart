import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:global_dharma_sharing/models/country_sending_model.dart';
import 'package:global_dharma_sharing/models/file_transfer_model.dart';
import 'package:global_dharma_sharing/models/leaderboard_model.dart';
import 'package:global_dharma_sharing/models/settings_model.dart';
import 'package:global_dharma_sharing/providers/tts_mute_notifier.dart';
import 'package:global_dharma_sharing/providers/video_feed_visibility_notifier.dart';
import 'package:global_dharma_sharing/screens/main_navigation_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real device homepage starts selected content sending', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'auto_start_guide_shown': true});
    final model = FileTransferModel();
    await model.addTextContentForSending(
      title: 'real-device-smoke',
      text: '南无阿弥陀佛',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FileTransferModel>.value(value: model),
          ChangeNotifierProvider(create: (_) => SettingsModel()),
          ChangeNotifierProvider(create: (_) => CountrySendingModel()),
          ChangeNotifierProvider(create: (_) => LeaderboardModel()),
          ChangeNotifierProvider(create: (_) => VideoFeedVisibilityNotifier()),
          ChangeNotifierProvider(create: (_) => TtsMuteNotifier()),
        ],
        child: const MaterialApp(home: MainNavigationScreen()),
      ),
    );

    for (int i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    final startButton = find.text('开始发送');
    expect(startButton, findsWidgets);
    await tester.tap(startButton.first, warnIfMissed: false);

    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(deadline) &&
        model.currentSendingScripture.isEmpty &&
        !model.currentLog.contains('real-device-smoke') &&
        model.globalSentCount == 0 &&
        !model.currentLog.contains('失败')) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(model.currentLog.contains('失败'), isFalse, reason: model.currentLog);
    expect(
      model.currentSendingScripture.isNotEmpty ||
          model.currentLog.contains('real-device-smoke') ||
          model.globalSentCount > 0,
      isTrue,
      reason:
          'log=${model.currentLog}, preparing=${model.preparingSendMessage}',
    );

    model.stopTransfer();
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  });
}
