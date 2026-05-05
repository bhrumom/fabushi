import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings screen exposes a direct entry to practice privacy controls', () {
    final source = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(source, contains("import 'practice_privacy_screen.dart';"));
    expect(source, contains("title: '修行隐私'"));
    expect(source, contains("subtitle: '控制修行排行榜与公开记录的展示范围'"));
    expect(source, contains('builder: (_) => const PracticePrivacyScreen()'));
  });
}
