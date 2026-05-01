import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_dharma_sharing/main.dart';

void main() {
  testWidgets('App shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('正在初始化应用...'), findsOneWidget);
  });
}
