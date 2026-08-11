import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('native host runtime contract', () {
    late String androidMainActivity;
    late String androidGradle;
    late String iosAppDelegate;

    setUpAll(() {
      androidMainActivity = File(
        'android/app/src/main/kotlin/com/ombhrum/fabushi/MainActivity.kt',
      ).readAsStringSync();
      androidGradle = File('android/app/build.gradle.kts').readAsStringSync();
      iosAppDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    });

    test('shared Flutter/native channels stay stable across Android and iOS', () {
      const sharedChannels = <String>[
        'com.ombhrum.fabushi/memory',
        'com.ombhrum.fabushi/inbound_share',
      ];

      for (final channel in sharedChannels) {
        expect(
          androidMainActivity,
          contains(channel),
          reason: 'Android host is missing shared channel $channel',
        );
        expect(
          iosAppDelegate,
          contains(channel),
          reason: 'iOS host is missing shared channel $channel',
        );
      }
    });

    test('Android application id and native bootstrap stay stable', () {
      expect(androidGradle, contains('applicationId = "com.ombhrum.fabushi"'));
      expect(androidMainActivity, contains('package com.ombhrum.fabushi'));

      for (final library in <String>[
        'ggml-base',
        'ggml',
        'ggml-cpu',
        'llama',
      ]) {
        expect(
          androidMainActivity,
          contains('System.loadLibrary("$library")'),
          reason: 'Android host no longer preloads $library',
        );
      }
    });

    test('iOS Mahayana ABI symbols stay linked and process-visible', () {
      for (final symbol in <String>[
        'mahayana_runtime_force_link',
        'mahayana_runtime_create',
        'mahayana_product_execute',
        'fabushi_mahayana_product_execute',
      ]) {
        expect(
          iosAppDelegate,
          contains(symbol),
          reason: 'iOS host is missing ABI symbol $symbol',
        );
      }
    });
  });
}
