import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:global_dharma_sharing/screens/buddha_model_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android Buddha loading reaches a visible ready state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: BuddhaModelScreen(isVisible: true),
          ),
        ),
      ),
    );

    const readyBanner = '安卓佛像使用 three_dart 原生渲染';
    const failureTitle = '禅境展现遇到阻碍';
    final deadline = DateTime.now().add(const Duration(seconds: 150));

    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(seconds: 1));
      if (find.text(readyBanner).evaluate().isNotEmpty ||
          find.text(failureTitle).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(
      find.text(failureTitle),
      findsNothing,
      reason: '佛像加载进入失败态，请结合 [BuddhaDiag] 日志判断卡住阶段。',
    );
    expect(
      find.text(readyBanner),
      findsOneWidget,
      reason: '佛像加载在超时前没有进入可见的 ready 状态。',
    );
  });
}
