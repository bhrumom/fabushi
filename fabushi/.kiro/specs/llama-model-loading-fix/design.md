# Llama Model Loading Fix - Bugfix Design

## Overview

The Llama AI model fails to load on Android devices with a `LlamaException: Could not load model` error, despite the model file being present and the native libraries being correctly bundled. The root cause is that the `llama_cpp_dart` FFI binding cannot locate or link to the native libraries on Android, even though they are preloaded in MainActivity. The fix requires configuring the library path for Android similar to macOS, or ensuring the FFI binding can find the already-loaded native libraries.

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug - when the Llama model initialization is attempted on Android platform
- **Property (P)**: The desired behavior when model initialization is called on Android - the model should load successfully and be ready for inference
- **Preservation**: Existing macOS model loading behavior that must remain unchanged by the fix
- **LlamaInferenceService**: The service class in `lib/services/llm_inference_service_macos.dart` that wraps llama_cpp_dart functionality
- **Llama.libraryPath**: Static property in llama_cpp_dart that specifies where to find native libraries
- **System.loadLibrary()**: Android/Java method that preloads native libraries in MainActivity.kt
- **FFI (Foreign Function Interface)**: Dart's mechanism for calling native C/C++ code
- **jniLibs**: Android directory containing native shared libraries (.so files) for different architectures

## Bug Details

### Bug Condition

The bug manifests when the application attempts to initialize the Llama model on Android devices. The `LlamaInferenceService.initialize()` method successfully validates the model file but fails when `LlamaParent` tries to load the native llama.cpp library through FFI.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type InitializationContext
  OUTPUT: boolean
  
  RETURN input.platform == Platform.Android
         AND input.modelFileExists == true
         AND input.nativeLibrariesPreloaded == true
         AND modelInitializationFails(input.modelPath)
END FUNCTION
```

### Examples

- **Example 1**: User downloads Qwen2.5-0.5B model on Android, model file exists at `/data/user/0/com.ombhrum.fabushi/app_flutter/models/llm/qwen2.5-0.5b-instruct-q4_k_m.gguf`, native libraries are in jniLibs and preloaded in MainActivity, but `inferenceService.initialize(modelPath)` throws `LlamaException: Could not load model`

- **Example 2**: User switches to a different model on Android, the new model file is valid GGUF format, but initialization still fails with the same error

- **Example 3**: Same model and code work perfectly on macOS because `Llama.libraryPath` is set to the Frameworks directory

- **Edge case**: On Android emulator (x86_64), the bug occurs even though x86_64 native libraries are present in jniLibs

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- macOS model loading must continue to work exactly as before with the Frameworks directory path
- Model file validation (existence check, GGUF format check) must remain unchanged
- Error handling for missing files or invalid formats must remain unchanged
- Model initialization parameters (nCtx, nBatch, temperature, etc.) must remain unchanged
- Streaming inference behavior must remain unchanged

**Scope:**
All inputs that do NOT involve Android platform initialization should be completely unaffected by this fix. This includes:
- macOS platform model loading
- iOS platform model loading (if supported in future)
- Model file validation logic
- Inference generation logic
- Model disposal and cleanup

## Hypothesized Root Cause

Based on the bug description and code analysis, the most likely issues are:

1. **Missing Android Library Path Configuration**: The `Llama.libraryPath` is only set for macOS in the initialize method (lines 29-35 of llm_inference_service_macos.dart). Android requires a different approach because:
   - Native libraries are in APK's `lib/<abi>/` directory at runtime
   - Libraries are preloaded via `System.loadLibrary()` in MainActivity
   - The FFI binding may need explicit path or may need to use already-loaded libraries

2. **FFI Library Resolution Mismatch**: The `llama_cpp_dart` package may be trying to dynamically load libraries using `DynamicLibrary.open()` which doesn't work with Android's preloaded libraries. Android requires using `DynamicLibrary.process()` or `DynamicLibrary.executable()` to access already-loaded libraries.

3. **Library Dependency Chain Issues**: Even though MainActivity preloads libraries in correct order (ggml-base → ggml → ggml-cpu → llama), the Dart FFI layer may be trying to load them again independently, causing symbol resolution failures.

4. **Architecture-Specific Path Issues**: The jniLibs structure has architecture-specific subdirectories (arm64-v8a, x86_64), but the code doesn't detect or specify which architecture's libraries to use.

## Correctness Properties

Property 1: Bug Condition - Android Model Loading Success

_For any_ initialization request on Android platform where the model file exists and is valid GGUF format, and native libraries are present in jniLibs, the fixed LlamaInferenceService SHALL successfully initialize the model and make it ready for inference, returning without throwing LlamaException.

**Validates: Requirements 2.1, 2.2, 2.3**

Property 2: Preservation - macOS Model Loading Behavior

_For any_ initialization request on macOS platform, the fixed LlamaInferenceService SHALL produce exactly the same behavior as the original implementation, successfully loading models from the Frameworks directory and initializing with the same parameters.

**Validates: Requirements 3.1, 3.4, 3.5**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct (missing Android library path configuration and FFI resolution):

**File**: `lib/services/llm_inference_service_macos.dart`

**Function**: `initialize(String modelPath, {int? nCtx})`

**Specific Changes**:

1. **Add Android Platform Detection**: Add platform check for Android alongside the existing macOS check
   - Import `dart:io` to access `Platform.isAndroid`
   - Add conditional logic after line 28

2. **Configure Android Library Path**: Set `Llama.libraryPath` for Android to use process-loaded libraries
   - Option A: Set to empty string or null to use system-loaded libraries
   - Option B: Use `DynamicLibrary.process()` approach if llama_cpp_dart supports it
   - Option C: Set to the APK's native library directory path

3. **Add Android-Specific Library Loading Logic**: 
   ```dart
   if (Platform.isAndroid) {
     // Android libraries are preloaded in MainActivity via System.loadLibrary()
     // The FFI should use the already-loaded libraries from the process
     if (Llama.libraryPath == null) {
       // Try to use process-loaded libraries
       // This may require checking llama_cpp_dart implementation
       Llama.libraryPath = ''; // or appropriate value for Android
     }
   }
   ```

4. **Add Logging for Android Path**: Add debug logging to track library path resolution on Android
   - Log the detected platform
   - Log the library path being used
   - Log any FFI-specific configuration

5. **Verify Library Preloading**: Ensure MainActivity's library preloading is sufficient
   - Confirm the order: ggml-base → ggml → ggml-cpu → llama
   - Verify all architectures have complete library sets
   - Check for any missing dependencies

### Alternative Approaches

If the primary approach doesn't work:

**Alternative 1**: Modify llama_cpp_dart package to support Android's preloaded libraries
- Fork the package and add Android-specific FFI loading
- Use `DynamicLibrary.process()` instead of `DynamicLibrary.open()`

**Alternative 2**: Use JNI bridge instead of direct FFI
- Create a Kotlin/Java wrapper that calls native methods
- Use MethodChannel to communicate between Dart and native code

**Alternative 3**: Bundle libraries differently
- Place libraries in a location accessible to FFI
- Copy libraries to app's files directory at runtime

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code, then verify the fix works correctly and preserves existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm or refute the root cause analysis. If we refute, we will need to re-hypothesize.

**Test Plan**: Write tests that attempt to initialize the Llama model on Android with valid model files and verify that native libraries are accessible. Run these tests on the UNFIXED code to observe failures and understand the root cause.

**Test Cases**:
1. **Android Model Initialization Test**: Attempt to initialize Qwen2.5-0.5B model on Android device (will fail on unfixed code)
2. **Library Path Detection Test**: Log and verify what library path is being used on Android (will show null/incorrect on unfixed code)
3. **FFI Library Access Test**: Verify that preloaded libraries are accessible from Dart FFI (may fail on unfixed code)
4. **Architecture Detection Test**: Verify correct architecture (arm64-v8a vs x86_64) is detected (may show issues on unfixed code)

**Expected Counterexamples**:
- `LlamaException: Could not load model` thrown during initialization
- Possible causes: null library path, incorrect FFI loading mechanism, library not found in expected location

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed function produces the expected behavior.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := LlamaInferenceService.initialize_fixed(input.modelPath)
  ASSERT result.success == true
  ASSERT result.isInitialized == true
  ASSERT NO LlamaException thrown
END FOR
```

**Test Cases**:
1. **Android Initialization Success**: Initialize model on Android and verify success
2. **Android Inference Test**: Generate text on Android after initialization
3. **Multiple Model Loading**: Switch between different models on Android
4. **Architecture Coverage**: Test on both arm64-v8a (real device) and x86_64 (emulator)

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT LlamaInferenceService.initialize_original(input) = LlamaInferenceService.initialize_fixed(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many test cases automatically across the input domain
- It catches edge cases that manual unit tests might miss
- It provides strong guarantees that behavior is unchanged for all non-buggy inputs

**Test Plan**: Observe behavior on UNFIXED code first for macOS model loading, then write property-based tests capturing that behavior.

**Test Cases**:
1. **macOS Model Loading Preservation**: Verify macOS model initialization continues to work with Frameworks path
2. **Model Validation Preservation**: Verify file existence and GGUF format checks work the same
3. **Error Handling Preservation**: Verify same exceptions are thrown for invalid files
4. **Inference Behavior Preservation**: Verify streaming generation works identically on macOS

### Unit Tests

- Test Android platform detection logic
- Test library path configuration for Android vs macOS
- Test model file validation on both platforms
- Test error handling for missing libraries
- Test initialization with various model sizes

### Property-Based Tests

- Generate random valid model paths and verify initialization succeeds on Android
- Generate random model configurations (nCtx values) and verify they work on Android
- Generate random platform combinations and verify correct library path is used
- Test that all valid GGUF files can be loaded on Android

### Integration Tests

- Test full AI chat flow on Android device with real model
- Test model switching on Android (dispose old, initialize new)
- Test memory handling with large models on Android
- Test concurrent initialization attempts on Android
- Test app lifecycle (background/foreground) with loaded model on Android
