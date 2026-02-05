# Requirements Document

## Introduction

This feature addresses a type safety issue in the search functionality where the remote API returns string values for fields that the Flutter application expects to be integers. Specifically, pagination metadata fields (`total`, `limit`, `offset`) and potentially other numeric fields are being returned as strings from the Cloudflare Worker API, causing runtime type errors when the Dart code attempts to cast them directly to integers.

## Glossary

- **TextSearchService**: The Dart service class responsible for searching text content both locally and remotely
- **Pagination Metadata**: Information about search results including total count, limit, and offset values
- **Type Coercion**: The process of safely converting values from one type to another
- **API Response**: JSON data returned from the Cloudflare Worker backend

## Requirements

### Requirement 1

**User Story:** As a user searching for Buddhist texts, I want the search functionality to work reliably without crashes, so that I can find the content I need.

#### Acceptance Criteria

1. WHEN the TextSearchService receives a remote search response, THE TextSearchService SHALL safely parse all numeric fields regardless of whether they are returned as strings or integers
2. WHEN pagination metadata contains string values, THE TextSearchService SHALL convert them to integers without throwing type errors
3. IF a numeric field cannot be parsed, THEN THE TextSearchService SHALL use a sensible default value and log a warning
4. THE TextSearchService SHALL handle both string and integer types for the `id`, `total`, `limit`, and `offset` fields

### Requirement 2

**User Story:** As a developer maintaining the codebase, I want type-safe parsing utilities, so that similar issues don't occur in other parts of the application.

#### Acceptance Criteria

1. THE TextSearchService SHALL implement a reusable safe parsing method for integer fields
2. THE safe parsing method SHALL accept dynamic input and return nullable integers
3. THE safe parsing method SHALL handle null values, integer values, and string values
4. WHERE a string value is provided, THE safe parsing method SHALL attempt to parse it to an integer

### Requirement 3

**User Story:** As a user viewing search results, I want to see accurate pagination information, so that I know how many results were found.

#### Acceptance Criteria

1. WHEN search results are displayed, THE TextSearchService SHALL provide accurate pagination metadata
2. THE pagination metadata SHALL include total results count, current limit, and offset values
3. IF pagination parsing fails, THEN THE TextSearchService SHALL still return search results with default pagination values
4. THE TextSearchService SHALL log parsing errors for debugging purposes without affecting user experience
