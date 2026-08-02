#!/usr/bin/env bash
set -euo pipefail
rm -rf .test-runtime
mkdir -p .test-runtime/native .test-runtime/web
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -o .test-runtime/native/mahayana-app ./cmd/native
GOOS=js GOARCH=wasm go build -trimpath -o .test-runtime/web/mahayana-app.wasm ./cmd/webwasm
cp "$(go env GOROOT)/misc/wasm/wasm_exec.js" .test-runtime/web/wasm_exec.js
