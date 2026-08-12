import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/ai_backend_policy.dart';

void main() {
  tearDown(() {
    AiBackendPolicy.debugIsDesktopNativeOverride = null;
  });

  test('desktop products use the shared Mahayana Runtime label', () async {
    AiBackendPolicy.debugIsDesktopNativeOverride = true;

    expect(
      await AiBackendPolicy.activeBackendLabel(isMember: true),
      'Mahayana Runtime',
    );
  });

  test('non-desktop products use the first-party cloud API label', () async {
    AiBackendPolicy.debugIsDesktopNativeOverride = false;

    expect(
      await AiBackendPolicy.activeBackendLabel(isMember: false),
      '云端 API',
    );
  });
}
