#!/usr/bin/env bash
set -euo pipefail

: "${SOURCE_SHA:?SOURCE_SHA is required}"
: "${RELEASE_TARGET:?RELEASE_TARGET is required}"
: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"

case "$RELEASE_TARGET" in
  macos)
    required_checks=('CI result' 'Electron desktop result')
    ;;
  ios|android)
    required_checks=('CI result' 'Native mobile result')
    ;;
  both)
    required_checks=('CI result' 'Electron desktop result' 'Native mobile result')
    ;;
  *)
    echo "Unsupported RELEASE_TARGET '$RELEASE_TARGET'." >&2
    exit 2
    ;;
esac

compare_json="$(gh api "repos/$GITHUB_REPOSITORY/compare/main...$SOURCE_SHA")"
status="$(printf '%s' "$compare_json" | jq -r '.status // "unknown"')"
ahead_by="$(printf '%s' "$compare_json" | jq -r '.ahead_by // -1')"
if [ "$status" != identical ] && [ "$status" != behind ]; then
  echo "Release source $SOURCE_SHA is not on protected main history (compare status: $status, ahead_by: $ahead_by)." >&2
  exit 1
fi
if [ "$ahead_by" != 0 ]; then
  echo "Release source $SOURCE_SHA contains commits not present on main (ahead_by=$ahead_by)." >&2
  exit 1
fi

checks_json="$(gh api --paginate --slurp "repos/$GITHUB_REPOSITORY/commits/$SOURCE_SHA/check-runs?per_page=100")"
for required in "${required_checks[@]}"; do
  conclusion="$(printf '%s' "$checks_json" | jq -r --arg required "$required" '[.[].check_runs[] | select(.name == $required and .status == "completed")] | sort_by(.completed_at) | last | .conclusion // "missing"')"
  if [ "$conclusion" != success ]; then
    echo "Required release gate '$required' is '$conclusion' for $SOURCE_SHA." >&2
    exit 1
  fi
  echo "Release gate '$required' is green for $SOURCE_SHA."
done

{
  echo '## Canonical release source gate'
  echo
  echo "- Source: \`$SOURCE_SHA\`"
  echo "- Target: \`$RELEASE_TARGET\`"
  echo '- Protected main ancestry: verified'
  for required in "${required_checks[@]}"; do
    echo "- $required: success"
  done
} >> "$GITHUB_STEP_SUMMARY"
