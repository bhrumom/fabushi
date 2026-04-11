# Bug Condition Exploration Test Documentation

## Test File Created
`test/unit/services/llama_inference_service_android_test.dart`

## Test Purpose
This test implements **Property 1: Bug Condition - Android Model Loading Failure** as specified in the bugfix design document.

## Test Structure

### Main Test: "Property 1: Android model initialization succeeds with valid GGUF file"

This test verifies the bug condition and expected behavior:

**Bug Condition (from design.md):**
- `input.platform == Platform.Android`
- `input.modelFileExists == true`
- `input.nativeLibrariesPreloaded == true`

**Expected Behavior:**
- Model loads successfully without throwing LlamaException
- `service.isInitialized == true`
- `service.modelPath` equals the provided model path

**Test Approach:**
1. Creates a minimal valid GGUF file with proper magic bytes (0x47 0x47 0x55 0x46)
2. Verifies all preconditions are met (Android platform, file exists, valid GGUF format)
3. Attempts to initialize the LlamaInferenceService
4. On SUCCESS: Confirms the bug is fixed
5. On FAILURE: Documents the counterexample with detailed information

### Scoped Property Tests

Two additional tests implement a scoped property-based testing approach:

1. **"Property 1 (Scoped): Multiple model paths should all succeed on Android"**
   - Tests with different file paths to verify the property holds across various valid inputs
   - Paths tested: `model1.gguf`, `model2.gguf`, `subdir/model3.gguf`

2. **"Property 1 (Scoped): Different nCtx values should all succeed on Android"**
   - Tests with different context sizes: 256, 512, 1024, 2048
   - Verifies the property holds across different configuration parameters

## Expected Outcomes

### On UNFIXED Code (Current State)
The test is **EXPECTED TO FAIL** with:
- Exception type: `LlamaException` or similar
- Exception message: "Could not load model" or similar
- This failure **CONFIRMS THE BUG EXISTS**

The test will output detailed counterexample information:
```
COUNTEREXAMPLE DOCUMENTED:
  Platform: Android
  Model file exists: true
  Model file path: /path/to/test_model.gguf
  Model file size: X bytes
  GGUF format valid: true
  Native libraries preloaded: true (MainActivity.kt)
  Error: LlamaException: Could not load model

ROOT CAUSE ANALYSIS:
  The bug occurs because Llama.libraryPath is only set for macOS.
  On Android, the FFI binding cannot locate the preloaded native
  libraries, even though they are loaded via System.loadLibrary()
  in MainActivity.kt.
```

### On FIXED Code (After Implementation)
The test should **PASS**, confirming:
- Model initialization succeeds on Android
- No LlamaException is thrown
- Service is properly initialized
- Expected behavior is satisfied

## Running the Test

### On Android Device/Emulator
```bash
flutter test test/unit/services/llama_inference_service_android_test.dart
```

### On Non-Android Platforms
The test will be skipped with message:
```
Skipping Android-specific test on [platform]
```

## Test Validation

The test file has been validated:
- ✓ No syntax errors (verified with getDiagnostics)
- ✓ Proper imports and structure
- ✓ Follows Flutter test conventions
- ✓ Implements scoped PBT approach for deterministic bug
- ✓ Includes detailed counterexample documentation
- ✓ Validates requirements 1.1, 1.3, 2.1

## Next Steps

1. Run this test on an Android device/emulator to observe the failure
2. Document the actual counterexample output
3. Proceed to Task 2: Write preservation property tests
4. Implement the fix in Task 3
5. Re-run this test to verify the fix works (test should pass)

## Notes

- The test uses a minimal GGUF file (just header with magic bytes) to avoid needing large model files
- Native library preloading is verified in `MainActivity.kt` companion object
- The test is designed to be deterministic and reproducible
- Counterexample documentation helps understand the root cause
