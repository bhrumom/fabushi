#!/usr/bin/env bash
set -euo pipefail

branch="${TARGET_BRANCH:?TARGET_BRANCH is required}"
targets=(
  ai-backend/src/server.js
  fabushi/web/alipay-login-functions.js
  fabushi/web/src/handlers/meditation.js
  fabushi/web/src/routes/meditation-routes.js
  fabushi/web/src/router.js
  .github/workflows/native-mobile.yml
)

patch_file="$(mktemp)"
trap 'rm -f "$patch_file"' EXIT

git diff --binary -- "${targets[@]}" > "$patch_file"
if [ ! -s "$patch_file" ]; then
  echo 'Large-file hardening already has no pending target diff.'
  exit 0
fi

validate() {
  node --check ai-backend/src/server.js
  printf '{"type":"module"}\n' > fabushi/web/package.json
  trap 'rm -f fabushi/web/package.json "$patch_file"' EXIT
  node --check fabushi/web/alipay-login-functions.js
  node --check fabushi/web/src/handlers/meditation.js
  node --check fabushi/web/src/routes/meditation-routes.js
  node --check fabushi/web/src/router.js
  node fabushi/web/tests/router-meditation-auth.test.js
  rm -f fabushi/web/package.json
  trap 'rm -f "$patch_file"' EXIT
  ! grep -q 'dacheng-codex-local-dev-secret' ai-backend/src/server.js
  ! grep -q 'mock_alipay_user_' fabushi/web/alipay-login-functions.js
  ! grep -q 'createLegacyMeditationToken' fabushi/web/src/router.js
  grep -q 'rust-toolchain@1.98.0' .github/workflows/native-mobile.yml
  grep -q 'cargo install cargo-ndk --version 4.1.2 --locked' .github/workflows/native-mobile.yml
}

already_hardened() {
  ! grep -q 'dacheng-codex-local-dev-secret' ai-backend/src/server.js &&
  ! grep -q 'mock_alipay_user_' fabushi/web/alipay-login-functions.js &&
  grep -q "import { verifyToken } from '../../auth-utils.js';" fabushi/web/src/handlers/meditation.js &&
  ! grep -q 'createLegacyMeditationToken' fabushi/web/src/router.js &&
  grep -q 'rust-toolchain@1.98.0' .github/workflows/native-mobile.yml &&
  grep -q 'cargo install cargo-ndk --version 4.1.2 --locked' .github/workflows/native-mobile.yml
}

git config user.name 'fabushi-security-bot'
git config user.email 'actions@users.noreply.github.com'
git reset --hard

for attempt in 1 2 3; do
  git fetch --no-tags origin "$branch"
  git checkout -B "$branch" "origin/$branch"
  if already_hardened; then
    echo 'Large-file hardening is already present on the remote branch.'
    exit 0
  fi
  if ! git apply --3way "$patch_file"; then
    git reset --hard "origin/$branch"
    echo "Unable to reapply hardening patch on attempt $attempt." >&2
    exit 1
  fi
  validate
  git add -- "${targets[@]}"
  git commit -m 'security: finish large-file hardening fixes'
  if git push origin "HEAD:$branch"; then
    echo 'Large-file hardening committed to the PR branch.'
    exit 0
  fi
  echo "Remote advanced during push attempt $attempt; rebasing hardening patch onto latest head." >&2
  git reset --hard
  sleep 2
done

echo 'Unable to publish large-file hardening after three serialized retries.' >&2
exit 1
