#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
LEGACY_DIR="$ROOT/fabushi/web"
PLATFORM_DIR="$ROOT/third_party/mahayana/mahayana-rs/mahayana-platform-worker"
WRANGLER_VERSION="${WRANGLER_VERSION:-4}"
PLATFORM_URL="${PLATFORM_URL:-https://mahayana-platform.bhrumom.workers.dev}"

: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}"
: "${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID is required}"
command -v jq >/dev/null
command -v openssl >/dev/null

secret_names() {
  local environment="$1"
  (
    cd "$LEGACY_DIR"
    npx --yes "wrangler@${WRANGLER_VERSION}" secret list --env "$environment" --format json \
      | jq -r '.[].name' \
      | sort -u
  )
}

contains_name() {
  local names="$1"
  local expected="$2"
  grep -Fxq "$expected" <<<"$names"
}

score_environment() {
  local names="$1"
  local score=0
  contains_name "$names" ALIPAY_PRIVATE_KEY && score=$((score + 4)) || true
  contains_name "$names" RESEND_API_KEY && score=$((score + 2)) || true
  printf '%s' "$score"
}

printf '%s\n' 'Inspecting legacy Worker secret names only; secret values are never read.'
dev_names="$(secret_names development)"
prod_names="$(secret_names production)"
dev_score="$(score_environment "$dev_names")"
prod_score="$(score_environment "$prod_names")"

if (( dev_score == 0 && prod_score == 0 )); then
  echo 'Neither legacy Worker environment has the existing Alipay/registration provider secrets.' >&2
  exit 20
fi

if (( dev_score >= prod_score )); then
  bridge_env=development
  bridge_url='https://fabushi-flutter-web-dev.bhrumom.workers.dev'
  bridge_names="$dev_names"
else
  bridge_env=production
  bridge_url='https://api.ombhrum.com'
  bridge_names="$prod_names"
fi

if ! contains_name "$bridge_names" ALIPAY_PRIVATE_KEY; then
  echo "Selected legacy environment $bridge_env does not have ALIPAY_PRIVATE_KEY; refusing fake Alipay rollout." >&2
  exit 21
fi

alipay_ready=true
email_ready=false
contains_name "$bridge_names" RESEND_API_KEY && email_ready=true || true
printf 'Selected deployed identity bridge: %s (Alipay=%s, registration email=%s)\n' "$bridge_env" "$alipay_ready" "$email_ready"

bridge_secret="$(openssl rand -base64 48 | tr -d '\n')"
echo "::add-mask::$bridge_secret"

# The legacy bridge code is deployed separately through the protected main production pipeline.
# This repair step only rotates a dedicated server-to-server proof and tells both deployed Workers
# where the other side lives. Values never enter the repository or browser-visible responses.
(
  cd "$LEGACY_DIR"
  printf '%s' "$bridge_secret" | npx --yes "wrangler@${WRANGLER_VERSION}" secret put AUTH_PROVIDER_BRIDGE_SECRET --env "$bridge_env" >/dev/null
  printf '%s' "$PLATFORM_URL" | npx --yes "wrangler@${WRANGLER_VERSION}" secret put AUTH_PROVIDER_BRIDGE_RETURN_BASE --env "$bridge_env" >/dev/null
)
(
  cd "$PLATFORM_DIR"
  printf '%s' "$bridge_secret" | npx --yes "wrangler@${WRANGLER_VERSION}" secret put AUTH_PROVIDER_BRIDGE_SECRET >/dev/null
  printf '%s' "$bridge_url" | npx --yes "wrangler@${WRANGLER_VERSION}" secret put AUTH_PROVIDER_BRIDGE_URL >/dev/null
)

capabilities="$(curl --fail --silent --show-error --retry 8 --retry-all-errors --retry-delay 3 \
  -H "X-Fabushi-Auth-Bridge: $bridge_secret" \
  "$bridge_url/api/internal/auth-provider/capabilities")"
jq -e '.ok == true and .alipay == true' <<<"$capabilities" >/dev/null
if [[ "$email_ready" == true ]]; then
  jq -e '.email == true' <<<"$capabilities" >/dev/null
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "bridge_env=$bridge_env"
    echo "bridge_url=$bridge_url"
    echo "alipay_ready=$alipay_ready"
    echo "email_ready=$email_ready"
  } >>"$GITHUB_OUTPUT"
fi

printf 'Identity bridge proof configured: %s (Alipay=%s, registration email=%s)\n' "$bridge_url" "$alipay_ready" "$email_ready"
