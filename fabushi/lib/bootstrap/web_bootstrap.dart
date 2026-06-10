import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/di/injection.dart';
import 'web_deferred_startup.dart' deferred as deferred_startup;
import 'web_instant_app.dart';

Future<void> bootstrapApplication() async {
  debugPrint('⚡ [web] App starting with minimal first chunk...');

  runZonedGuarded(() {
    setupDependencies();

    if (kDebugMode) {
      AppConfig.printConfigInfo();
    }

    runApp(const WebInstantApp());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startDeferredWebServices());
    });
  }, (error, stackTrace) {
    debugPrint('⚠️ [web] bootstrap error: $error');
  });
}

Future<void> _startDeferredWebServices() async {
  await Future<void>.delayed(const Duration(milliseconds: 1200));
  try {
    await deferred_startup.loadLibrary();
    await deferred_startup.startDeferredWebServices();
  } catch (error) {
    debugPrint('⚠️ [web] deferred startup bootstrap failed: $error');
  }
}
