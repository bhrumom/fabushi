#!/usr/bin/env bash
set -euo pipefail

: "${SOURCE_SHA:?SOURCE_SHA is required}"
: "${RELEASE_TARGET:?RELEASE_TARGET is required}"
RELEASE_TIER="${RELEASE_TIER:-formal}"
REPO="${GITHUB_REPOSITORY:-bhrumom/fabushi}"

case "$RELEASE_TIER" in
  test|formal) ;;
  *) echo "Unsupported RELEASE_TIER=$RELEASE_TIER" >&2; exit 2 ;;
esac
case "$SOURCE_SHA" in
  ''|*[!0-9a-f]*) echo "SOURCE_SHA must be a lowercase hexadecimal commit SHA" >&2; exit 2 ;;
esac
[ "${#SOURCE_SHA}" -eq 40 ] || { echo "SOURCE_SHA must be 40 characters" >&2; exit 2; }

main_sha="$(gh api "repos/$REPO/commits/main" --jq '.sha')"
test -n "$main_sha"
if [ "$SOURCE_SHA" != "$main_sha" ]; then
  compare_status="$(gh api "repos/$REPO/compare/$SOURCE_SHA...$main_sha" --jq '.status')"
  case "$compare_status" in
    ahead|identical) ;;
    *) echo "Release source $SOURCE_SHA is not protected-main ancestry of current main $main_sha (status=$compare_status)." >&2; exit 1 ;;
  esac
fi

{
  echo '## Release source gate'
  echo "- source: \`$SOURCE_SHA\`"
  echo "- current main: \`$main_sha\`"
  echo "- target: \`$RELEASE_TARGET\`"
  echo "- tier: \`$RELEASE_TIER\`"
} >> "$GITHUB_STEP_SUMMARY"

if [ "$RELEASE_TIER" = test ]; then
  {
    echo '- behavioral tests required: `none`'
    echo '- automatic E2E required: `none`'
    echo '- policy: FCM-023/024 test publication intentionally performs no product tests.'
  } >> "$GITHUB_STEP_SUMMARY"
  exit 0
fi

: "${FABUSHI_FORMAL_MCP_RUN_IDS:?Formal release requires comma-separated FABUSHI_FORMAL_MCP_RUN_IDS from manually dispatched exact-candidate App-owned MCP runner validations}"

expected=()
case "$RELEASE_TARGET" in
  macos) expected+=(.github/workflows/macos-mcp-runner.yml) ;;
  windows) expected+=(.github/workflows/windows-mcp-runner.yml) ;;
  linux) expected+=(.github/workflows/interactive-runner-mcp.yml) ;;
  android) expected+=(.github/workflows/android-mcp-runner.yml) ;;
  ios) expected+=(.github/workflows/ios-mcp-runner.yml) ;;
  desktop) expected+=(.github/workflows/macos-mcp-runner.yml .github/workflows/windows-mcp-runner.yml .github/workflows/interactive-runner-mcp.yml) ;;
  both|all) expected+=(.github/workflows/macos-mcp-runner.yml .github/workflows/windows-mcp-runner.yml .github/workflows/interactive-runner-mcp.yml .github/workflows/android-mcp-runner.yml .github/workflows/ios-mcp-runner.yml) ;;
  *) echo "Unsupported RELEASE_TARGET=$RELEASE_TARGET" >&2; exit 2 ;;
esac

declare -A passed=()
IFS=',' read -r -a run_ids <<< "$FABUSHI_FORMAL_MCP_RUN_IDS"
for raw in "${run_ids[@]}"; do
  run_id="${raw//[[:space:]]/}"
  test -n "$run_id" || continue
  run="$(gh api "repos/$REPO/actions/runs/$run_id")"
  event="$(jq -r '.event // empty' <<<"$run")"
  head_sha="$(jq -r '.head_sha // empty' <<<"$run")"
  conclusion="$(jq -r '.conclusion // empty' <<<"$run")"
  path="$(jq -r '.path // empty' <<<"$run")"
  test "$event" = workflow_dispatch || { echo "Formal MCP run $run_id was not manually dispatched (event=$event)." >&2; exit 1; }
  test "$head_sha" = "$SOURCE_SHA" || { echo "Formal MCP run $run_id head $head_sha != source $SOURCE_SHA." >&2; exit 1; }
  test "$conclusion" = success || { echo "Formal MCP run $run_id conclusion=$conclusion." >&2; exit 1; }
  case "$path" in
    .github/workflows/macos-mcp-runner.yml|.github/workflows/windows-mcp-runner.yml|.github/workflows/interactive-runner-mcp.yml|.github/workflows/android-mcp-runner.yml|.github/workflows/ios-mcp-runner.yml) ;;
    *) echo "Formal run $run_id came from non-authoritative workflow $path." >&2; exit 1 ;;
  esac
  passed["$path"]="$run_id"
  echo "- MCP validation run: \`$run_id\` path=\`$path\` exact-source/manual/success" >> "$GITHUB_STEP_SUMMARY"
done

for path in "${expected[@]}"; do
  if [ -z "${passed[$path]:-}" ]; then
    echo "Formal release requires successful exact-source official-MCP completion from $path" >&2
    exit 1
  fi
done

echo '- formal behavioral gate: passed only through manually dispatched App-owned runner sessions finished by the external Fabushi official MCP.' >> "$GITHUB_STEP_SUMMARY"
