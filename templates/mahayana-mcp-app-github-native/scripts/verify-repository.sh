#!/usr/bin/env bash
set -euo pipefail
required=(
  LICENSE NOTICE CONTRIBUTING.md SECURITY.md tool-contract.json tools.json permissions.json mcp-app.yaml
  common/plugin.json common/ui/index.html common/ui/app.js common/ui/styles.css
  internal/contract/contract.go cmd/native/main.go cmd/webwasm/main.go runtime/web/worker.js
  tests/native-contract.mjs tests/web-wasm-contract.mjs tests/mcp-apps-conformance.mjs
  .github/CODEOWNERS .github/ISSUE_TEMPLATE/bug.yml .github/PULL_REQUEST_TEMPLATE.md
  .github/workflows/pr-untrusted.yml .github/workflows/main-trusted.yml .github/workflows/release-trusted.yml
  .github/rulesets/main.json .github/rulesets/release-tags.json
)
for path in "${required[@]}"; do
  test -s "$path" || { echo "missing required file: $path" >&2; exit 1; }
done
! grep -R --line-number -E 'pull_request_target:|Mcp-Session-Id|mcp-session-id|createLegacyMcpHandler|McpAgent|WorkerTransport|mcp-2025-06-18'   --exclude='verify-repository.sh' --exclude='verify-untrusted-workflow.sh' .github common cmd internal runtime scripts tests
node -e "const fs=require('fs'); for (const f of ['tools.json','permissions.json','tool-contract.json','common/plugin.json','.github/rulesets/main.json','.github/rulesets/release-tags.json']) JSON.parse(fs.readFileSync(f,'utf8'))"
grep -F 'io.modelcontextprotocol/ui' mcp-app.yaml >/dev/null
grep -F '2026-01-26' mcp-app.yaml >/dev/null
grep -F 'text/html;profile=mcp-app' mcp-app.yaml >/dev/null
