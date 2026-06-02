import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/widgets/buddha_model_loading_overlay.dart';

void main() {
  group('BuddhaModelLoadingOverlay', () {
    testWidgets('shows model download progress', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BuddhaModelLoadingOverlay.loading(
            progress: 0.42,
            label: '正在安奉佛像...',
          ),
        ),
      );

      expect(find.text('正在安奉佛像...'), findsOneWidget);
      expect(find.text('下载进度 42%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('keeps retry action visible and tappable on failure', (
      tester,
    ) async {
      var retryCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: BuddhaModelLoadingOverlay.failed(
            failureDetails: '网络连接失败',
            onRetry: () => retryCount++,
          ),
        ),
      );

      expect(find.text('3D佛像下载失败'), findsOneWidget);
      expect(find.text('网络连接失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);

      await tester.tap(find.text('重试'));
      expect(retryCount, 1);
    });
  });
}
