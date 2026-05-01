import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/llm_inference_service_macos.dart';

/// Bug Condition Exploration Test for Android Model Loading
///
/// **Validates: Requirements 1.1, 1.3, 2.1**
///
/// **Property 1: Bug Condition** - Android Model Loading Failure
///
/// This test encodes the expected behavior: model initialization should succeed
/// on Android when model file exists and is valid GGUF format.
///
/// **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists.
///
/// **Bug Condition from Design**:
/// - input.platform == Platform.Android
/// - input.modelFileExists == true
/// - input.nativeLibrariesPreloaded == true (verified in MainActivity.kt)
///
/// **Expected Behavior**: Model loads successfully without throwing LlamaException
///
/// **EXPECTED OUTCOME ON UNFIXED CODE**: Test FAILS with LlamaException
///
/// **Scoped PBT Approach**: For this deterministic bug, we scope the property
/// to the concrete failing case to ensure reproducibility.
void main() {
  group('Android Model Loading Bug Condition Exploration', () {
    late LlamaInferenceService service;
    late Directory tempDir;
    late File testModelFile;

    setUp(() async {
      service = LlamaInferenceService.instance;

      // Create a temporary directory for test model files
      tempDir = await Directory.systemTemp.createTemp('llama_test_');

      // Create a minimal valid GGUF file for testing
      // GGUF magic bytes: 0x47 0x47 0x55 0x46 ("GGUF")
      testModelFile = File('${tempDir.path}/test_model.gguf');

      // Write minimal GGUF header (magic bytes + version + metadata count)
      final ggufHeader = <int>[
        0x47, 0x47, 0x55, 0x46, // Magic: "GGUF"
        0x03, 0x00, 0x00, 0x00, // Version: 3 (little-endian)
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Tensor count: 0
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Metadata count: 0
      ];

      await testModelFile.writeAsBytes(ggufHeader);
    });

    tearDown(() async {
      // Clean up test files
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }

      // Dispose service to clean up any loaded models
      try {
        await service.dispose();
      } catch (e) {
        // Ignore disposal errors in tests
      }
    });

    test(
      'Property 1: Android model initialization succeeds with valid GGUF file',
      () async {
        // Skip test if not running on Android
        // This test is specifically for Android platform bug condition
        if (!Platform.isAndroid) {
          print(
            'Skipping Android-specific test on ${Platform.operatingSystem}',
          );
          return;
        }

        // Verify preconditions (Bug Condition from design):
        // 1. Platform is Android
        expect(
          Platform.isAndroid,
          isTrue,
          reason: 'Test must run on Android platform',
        );

        // 2. Model file exists
        expect(
          await testModelFile.exists(),
          isTrue,
          reason: 'Model file must exist',
        );

        // 3. Model file is valid GGUF format
        final raf = await testModelFile.open();
        final header = await raf.read(4);
        await raf.close();
        expect(
          header,
          equals([0x47, 0x47, 0x55, 0x46]),
          reason: 'Model file must have valid GGUF magic bytes',
        );

        // 4. Native libraries are preloaded (verified in MainActivity.kt companion object)
        // We assume this is true if the test runs, as MainActivity loads libraries on startup
        print(
          'Native libraries preloaded in MainActivity.kt: '
          'ggml-base, ggml, ggml-cpu, llama',
        );

        // **EXPECTED BEHAVIOR**: Model should load successfully
        // **ON UNFIXED CODE**: This will throw LlamaException: Could not load model
        // **ON FIXED CODE**: This will succeed and isInitialized will be true

        print('Attempting to initialize model on Android...');
        print('Model path: ${testModelFile.path}');

        try {
          await service.initialize(testModelFile.path, nCtx: 512);

          // If we reach here, initialization succeeded
          expect(
            service.isInitialized,
            isTrue,
            reason: 'Service should be initialized after successful load',
          );
          expect(
            service.modelPath,
            equals(testModelFile.path),
            reason: 'Service should track the loaded model path',
          );

          print('✓ Model initialization succeeded on Android');
          print('✓ Bug is FIXED - expected behavior is satisfied');
        } catch (e) {
          // **COUNTEREXAMPLE FOUND**: This is the bug manifestation
          print('✗ Model initialization FAILED on Android');
          print('✗ Exception type: ${e.runtimeType}');
          print('✗ Exception message: $e');
          print('');
          print('COUNTEREXAMPLE DOCUMENTED:');
          print('  Platform: Android (${Platform.operatingSystem})');
          print('  Model file exists: true');
          print('  Model file path: ${testModelFile.path}');
          print('  Model file size: ${await testModelFile.length()} bytes');
          print('  GGUF format valid: true');
          print('  Native libraries preloaded: true (MainActivity.kt)');
          print('  Error: $e');
          print('');
          print('ROOT CAUSE ANALYSIS:');
          print(
            '  The bug occurs because Llama.libraryPath is only set for macOS.',
          );
          print(
            '  On Android, the FFI binding cannot locate the preloaded native',
          );
          print(
            '  libraries, even though they are loaded via System.loadLibrary()',
          );
          print('  in MainActivity.kt.');
          print('');
          print('This test FAILURE is EXPECTED on unfixed code.');
          print('It confirms the bug exists and provides a counterexample.');

          // Re-throw to fail the test (expected on unfixed code)
          rethrow;
        }
      },
      skip: !Platform.isAndroid
          ? 'Android-specific test - run on Android device/emulator'
          : null,
    );

    test(
      'Property 1 (Scoped): Multiple model paths should all succeed on Android',
      () async {
        // Skip test if not running on Android
        if (!Platform.isAndroid) {
          print(
            'Skipping Android-specific test on ${Platform.operatingSystem}',
          );
          return;
        }

        // Test with multiple model file paths to verify the property holds
        // across different valid inputs (scoped PBT approach)
        final testCases = [
          '${tempDir.path}/model1.gguf',
          '${tempDir.path}/model2.gguf',
          '${tempDir.path}/subdir/model3.gguf',
        ];

        for (final modelPath in testCases) {
          // Create model file
          final modelFile = File(modelPath);
          await modelFile.create(recursive: true);

          // Write minimal GGUF header
          final ggufHeader = <int>[
            0x47, 0x47, 0x55, 0x46, // Magic: "GGUF"
            0x03, 0x00, 0x00, 0x00, // Version: 3
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Tensor count: 0
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Metadata count: 0
          ];
          await modelFile.writeAsBytes(ggufHeader);

          print('Testing model path: $modelPath');

          try {
            await service.initialize(modelPath, nCtx: 512);
            expect(service.isInitialized, isTrue);
            print('  ✓ Initialization succeeded');

            // Dispose before next iteration
            await service.dispose();
          } catch (e) {
            print('  ✗ Initialization failed: $e');
            print('  COUNTEREXAMPLE: modelPath=$modelPath');
            rethrow;
          }
        }

        print('✓ All model paths initialized successfully on Android');
      },
      skip: !Platform.isAndroid
          ? 'Android-specific test - run on Android device/emulator'
          : null,
    );

    test(
      'Property 1 (Scoped): Different nCtx values should all succeed on Android',
      () async {
        // Skip test if not running on Android
        if (!Platform.isAndroid) {
          print(
            'Skipping Android-specific test on ${Platform.operatingSystem}',
          );
          return;
        }

        // Test with different context sizes to verify the property holds
        // across different configuration parameters
        final nCtxValues = [256, 512, 1024, 2048];

        for (final nCtx in nCtxValues) {
          print('Testing nCtx: $nCtx');

          try {
            await service.initialize(testModelFile.path, nCtx: nCtx);
            expect(service.isInitialized, isTrue);
            print('  ✓ Initialization succeeded with nCtx=$nCtx');

            // Dispose before next iteration
            await service.dispose();
          } catch (e) {
            print('  ✗ Initialization failed with nCtx=$nCtx: $e');
            print('  COUNTEREXAMPLE: nCtx=$nCtx');
            rethrow;
          }
        }

        print('✓ All nCtx values initialized successfully on Android');
      },
      skip: !Platform.isAndroid
          ? 'Android-specific test - run on Android device/emulator'
          : null,
    );
  });
}
