#!/usr/bin/env bash
set -euo pipefail
workflow=.github/workflows/pr-untrusted.yml
grep -Eq '^  pull_request:$' "$workflow"
grep -Eq '^permissions:$' "$workflow"
grep -Eq '^  contents: read$' "$workflow"
! grep -E '\$\{\{[[:space:]]*secrets\.' "$workflow"
! grep -E 'pull_request_target:|id-token:[[:space:]]*write|contents:[[:space:]]*write|attest-build-provenance|gh release|wrangler deploy|npm publish|upload-artifact@|actions/cache@' "$workflow"
