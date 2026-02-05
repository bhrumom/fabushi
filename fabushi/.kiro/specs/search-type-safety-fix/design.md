# Design Document

## Overview

This design addresses the type safety issue in the `TextSearchService` where API responses contain numeric values as strings, causing runtime type errors. The solution implements robust type coercion utilities that safely handle mixed-type responses from the backend API.

## Architecture

### Current Flow
1. User enters search query in `SearchScreen`
2. `TextSearchService.searchRemote()` makes HTTP request to Cloudflare Worker API
3. JSON response is decoded
4. Response data is directly cast to expected types (causing failures)
5. `TextItem` objects are created from parsed data

### Proposed Flow
1. User enters search query in `SearchScreen`
2. `TextSearchService.searchRemote()` makes HTTP request to Cloudflare Worker API
3. JSON response is decoded
4. **Safe parsing utilities convert all dynamic values to expected types**
5. `TextItem` objects are created from safely parsed data

## Components and Interfaces

### 1. Safe Parsing Utilities

Add static utility methods to `TextSearchService` for type-safe parsing:

```dart
// Safe integer parsing - handles null, int, and string types
static int? _parseIntSafe(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

// Safe integer parsing with default value
static int _parseIntWithDefault(dynamic value, int defaultValue) {
  return _parseIntSafe(value) ?? defaultValue;
}
```

### 2. Enhanced Pagination Parsing

Update the pagination parsing logic in `searchRemote()`:

```dart
// Current (unsafe):
final pagination = dataMap['pagination'] as Map<String, dynamic>?;

// Proposed (safe):
final paginationRaw = dataMap['pagination'];
final pagination = paginationRaw != null ? {
  'total': _parseIntWithDefault(paginationRaw['total'], 0),
  'limit': _parseIntWithDefault(paginationRaw['limit'], 50),
  'offset': _parseIntWithDefault(paginationRaw['offset'], 0),
  'hasMore': paginationRaw['hasMore'] ?? false,
} : null;
```

### 3. TextItem Factory Enhancement

The existing `TextItem.fromJson()` factory already has safe ID parsing via `_parseIdSafe()`. We'll ensure consistency by using the same pattern for all numeric fields.

## Data Models

### TextItem
No changes needed - already implements safe ID parsing. The model correctly handles:
- `id`: nullable integer (safely parsed)
- `title`: string
- `content`: string  
- `filePath`: string (with fallback field names)
- `category`: string
- `preview`: nullable string

### Search Response Structure
```json
{
  "success": true,
  "data": {
    "results": [
      {
        "id": "123",  // May be string or int
        "title": "心经",
        "content": "...",
        "file_path": "...",
        "category": "经文"
      }
    ],
    "pagination": {
      "total": "104",    // Currently string, should handle as int
      "limit": "50",     // Currently string, should handle as int
      "offset": "0",     // Currently string, should handle as int
      "hasMore": true
    }
  },
  "query": "心经",
  "category": null
}
```

## Error Handling

### Parsing Failures
- **Strategy**: Graceful degradation with logging
- **Implementation**: 
  - Use `tryParse` methods that return null on failure
  - Provide sensible defaults (0 for counts, empty string for text)
  - Log warnings for debugging without breaking user experience

### Network Failures
- **Existing**: Already falls back to local search
- **No changes needed**: Current error handling is appropriate

### Logging Strategy
```dart
if (pagination != null) {
  print('📊 分页信息: total=${pagination['total']}, limit=${pagination['limit']}, offset=${pagination['offset']}');
}
```

## Testing Strategy

### Unit Testing Approach
1. Test `_parseIntSafe()` with various input types:
   - Null values → returns null
   - Integer values → returns same integer
   - Valid string numbers → returns parsed integer
   - Invalid strings → returns null
   - Other types → returns null

2. Test `_parseIntWithDefault()` with various inputs:
   - Null values → returns default
   - Valid integers → returns integer
   - Valid strings → returns parsed integer
   - Invalid values → returns default

### Integration Testing
1. Mock API responses with string numeric values
2. Verify search results are correctly parsed
3. Verify pagination metadata is correctly displayed
4. Verify no type errors are thrown

### Manual Testing
1. Perform actual search queries
2. Verify results display correctly
3. Verify pagination information shows accurate counts
4. Check console logs for any parsing warnings

## Implementation Notes

### Backward Compatibility
- Solution handles both string and integer responses
- No breaking changes to existing API contracts
- Graceful handling of missing or malformed fields

### Performance Considerations
- Minimal overhead: simple type checks and parsing
- No additional network requests
- Parsing happens once per response

### Code Locations
- **Primary file**: `lib/services/text_search_service.dart`
- **Methods to modify**: `searchRemote()`, add new utility methods
- **No changes needed**: `TextItem.fromJson()` (already safe), `search()`, `getCategories()`
