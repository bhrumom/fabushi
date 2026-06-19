import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/ai_backend_policy.dart';
import 'package:global_dharma_sharing/services/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  });

  tearDown(() {
    AiBackendPolicy.debugIsDesktopNativeOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  test('routes desktop members to embedded OpenClaw in auto mode', () async {
    await AppSettings.setAiBackendModeName(AiBackendMode.auto.storageName);

    expect(
      await AiBackendPolicy.shouldUseEmbeddedOpenClaw(isMember: true),
      isTrue,
    );
    expect(
      await AiBackendPolicy.activeBackendLabel(isMember: true),
      '本机 OpenClaw',
    );
  });

  test('keeps non-member desktop auto mode on embedded OpenClaw', () async {
    await AppSettings.setAiBackendModeName(AiBackendMode.auto.storageName);

    expect(
      await AiBackendPolicy.shouldUseEmbeddedOpenClaw(isMember: false),
      isTrue,
    );
    expect(
      await AiBackendPolicy.activeBackendLabel(isMember: false),
      '本机 OpenClaw',
    );
  });

  test('allows members to force embedded OpenClaw', () async {
    await AppSettings.setAiBackendModeName(
      AiBackendMode.embeddedOpenClaw.storageName,
    );

    expect(
      await AiBackendPolicy.shouldUseEmbeddedOpenClaw(isMember: true),
      isTrue,
    );
  });

  test('respects cloud API override for members', () async {
    await AppSettings.setAiBackendModeName(AiBackendMode.cloudApi.storageName);

    expect(
      await AiBackendPolicy.shouldUseEmbeddedOpenClaw(isMember: true),
      isFalse,
    );
    expect(await AiBackendPolicy.activeBackendLabel(isMember: true), '云端 API');
  });
}
