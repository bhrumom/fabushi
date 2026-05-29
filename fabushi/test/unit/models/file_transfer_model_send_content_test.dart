import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/models/file_transfer_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('text selection exposes a preview before sending', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final model = FileTransferModel();
    addTearDown(model.dispose);
    await tester.pump(const Duration(milliseconds: 350));

    await model.addTextContentForSending(
      title: '心经片段',
      text: '观自在菩萨，行深般若波罗蜜多时。',
    );

    expect(model.hasFiles, isTrue);
    expect(model.selectedContentKind, '文本');
    expect(model.selectedContentTitle, '心经片段');
    expect(model.hasSelectedContentPreview, isTrue);
    expect(model.selectedContentPreviewText, contains('观自在菩萨'));
  });

  testWidgets('link history restores from persisted state', (tester) async {
    SharedPreferences.setMockInitialValues({
      'send_link_history_v1': jsonEncode([
        {
          'url': 'https://example.com/sutra',
          'title': '示例经文',
          'preview': '已读取的正文片段',
          'savedAt': '2026-05-29T08:00:00.000',
        },
      ]),
    });

    final model = FileTransferModel();
    addTearDown(model.dispose);

    await tester.pump(const Duration(milliseconds: 350));

    expect(model.linkHistory, hasLength(1));
    expect(model.linkHistory.first.url, 'https://example.com/sutra');
    expect(model.linkHistory.first.preview, contains('正文片段'));
  });
}
