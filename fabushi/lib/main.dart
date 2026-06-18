import 'package:flutter/material.dart';

import 'bootstrap/app_bootstrap.dart'
    if (dart.library.html) 'bootstrap/web_bootstrap.dart'
    if (dart.library.io) 'bootstrap/native_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapApplication();
}

/// Backward-compatible widget-test entrypoint.
///
/// Production startup intentionally goes through [bootstrapApplication] so Web and
/// native can keep separate first-paint paths. The legacy widget test imports
/// `main.dart` and pumps `MyApp` directly, so this tiny shell preserves that
/// contract without pulling native startup work into `main()`.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(child: Text('大乘')),
      ),
    );
  }
}
