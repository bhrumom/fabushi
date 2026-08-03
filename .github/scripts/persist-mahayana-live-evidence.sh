#!/usr/bin/env bash
set -euo pipefail

branch="${EVIDENCE_TARGET_BRANCH:?EVIDENCE_TARGET_BRANCH is required}"
path="${PERSISTED_EVIDENCE_PATH:?PERSISTED_EVIDENCE_PATH is required}"
message="${EVIDENCE_COMMIT_MESSAGE:?EVIDENCE_COMMIT_MESSAGE is required}"
snapshot="$(mktemp "${RUNNER_TEMP:-/tmp}/mahayana-live-evidence.XXXXXX")"
trap 'rm -f "$snapshot"' EXIT

# Preserve the just-generated evidence outside the checkout before moving to the
# latest task-branch tip. This avoids rebasing a generated evidence commit when
# another live job wins the push race.
cp "$path" "$snapshot"
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'

for attempt in 1 2 3 4 5; do
  git reset --hard HEAD
  git fetch origin "$branch"
  git checkout --detach --force "origin/$branch"
  mkdir -p "$(dirname "$path")"
  cp "$snapshot" "$path"
  git add "$path"

  if git diff --cached --quiet; then
    echo "Persisted evidence is unchanged at origin/$branch."
    exit 0
  fi

  git commit -m "$message"
  if git push origin "HEAD:$branch"; then
    exit 0
  fi

  echo "Evidence push race detected (attempt $attempt/5); retrying from the latest remote tip."
  sleep "$((attempt * 2))"
done

echo "Unable to persist $path after five non-force push attempts." >&2
exit 1
