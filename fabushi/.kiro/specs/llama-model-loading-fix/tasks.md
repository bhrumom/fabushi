# Implementation Plan

- [ ] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Android Model Loading Failure
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug exists
  - **Scoped PBT Approach**: For deterministic bugs, scope the property to the concrete failing case(s) to ensure reproducibility
  - Test that model initialization succeeds on Android when model file exists and is valid GGUF format
  - Test implementation details from Bug Condition in design: `input.platform == Platform.Android AND input.modelFileExists == true AND input.nativeLibrariesPreloaded == true`
  - The test assertions should match the Expected Behavior Properties from design: model loads successfully without throwing LlamaException
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found to understand root cause (e.g., "LlamaException: Could not load model" thrown during initialization)
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.3, 2.1_

- [ ] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - macOS Model Loading Behavior
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED code for non-buggy inputs (macOS platform)
  - Write property-based tests capturing observed behavior patterns from Preservation Requirements
  - Test that macOS model initialization continues to work with Frameworks path
  - Test that model file validation (existence check, GGUF format check) works the same
  - Test that error handling for missing files or invalid formats works the same
  - Property-based testing generates many test cases for stronger guarantees
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 3. Fix for Android model loading failure

  - [ ] 3.1 Implement the fix
    - Add Android platform detection in `initialize()` method
    - Configure `Llama.libraryPath` for Android to use process-loaded libraries
    - Add Android-specific library loading logic after line 28 in llm_inference_service_macos.dart
    - Set library path to empty string or appropriate value for Android to use preloaded libraries
    - Add debug logging for Android platform detection and library path
    - Verify MainActivity's library preloading order is correct (ggml-base → ggml → ggml-cpu → llama)
    - _Bug_Condition: isBugCondition(input) where input.platform == Platform.Android AND input.modelFileExists == true AND input.nativeLibrariesPreloaded == true_
    - _Expected_Behavior: Model loads successfully without throwing LlamaException, isInitialized == true_
    - _Preservation: macOS model loading with Frameworks path, model validation logic, error handling, inference behavior_
    - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 3.4, 3.5_

  - [ ] 3.2 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Android Model Loading Success
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior
    - When this test passes, it confirms the expected behavior is satisfied
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - _Requirements: 2.1, 2.2, 2.3_

  - [ ] 3.3 Verify preservation tests still pass
    - **Property 2: Preservation** - macOS Model Loading Behavior
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm all tests still pass after fix (no regressions)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
