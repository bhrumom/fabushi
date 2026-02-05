# Implementation Plan

- [x] 1. Add safe parsing utility methods to TextSearchService
  - Add `_parseIntSafe()` static method that handles null, int, and string types
  - Add `_parseIntWithDefault()` static method that returns default value on parse failure
  - Place methods near existing `_parseId()` method for consistency
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [ ] 2. Update searchRemote() method to use safe pagination parsing
  - Replace direct casting of pagination fields with safe parsing utilities
  - Use `_parseIntWithDefault()` for total, limit, and offset fields
  - Preserve existing hasMore boolean field handling
  - Update debug logging to show parsed integer values
  - _Requirements: 1.1, 1.2, 1.3, 3.1, 3.2, 3.3, 3.4_

- [ ] 3. Verify and test the fix
  - Run the application and perform search queries
  - Verify no type errors occur in console
  - Verify pagination information displays correctly
  - Check that search results are returned successfully
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 3.1, 3.2, 3.3_
