import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:global_dharma_sharing/screens/buddha_model_screen_android_three.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android three diagnostics reach ready without fallback error', (
    WidgetTester tester,
  ) async {
    final statuses = <String>[];
    String? error;
    var ready = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: AndroidThreeBuddhaView(
              rotationY: 0,
              isVisible: true,
              onStatus: statuses.add,
              onReady: () => ready = true,
              onError: (message) => error = message,
            ),
          ),
        ),
      ),
    );

    final deadline = DateTime.now().add(const Duration(seconds: 150));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(seconds: 1));
      if (ready || error != null) {
        break;
      }
    }

    debugPrint('[BuddhaDiag][test] statuses=${statuses.join(' -> ')}');

    expect(
      error,
      isNull,
      reason: 'Android Three 仍进入失败态，请结合 workflow artifact 与 [BuddhaDiag] 日志定位阶段。',
    );
    expect(
      ready,
      isTrue,
      reason: 'Android Three 在超时前没有进入 ready 状态；请查看 buddha_flutter_test.log 和 logcat artifact。',
    );
  });
}
