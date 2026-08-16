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
  (cd "$LEGACY_DIR" && npx --yes "wrangler@${WRANGLER_VERSION}" secret list --env "$environment" --format json | jq -r '.[].name' | sort -u)
}
contains_name() { grep -Fxq "$2" <<<"$1"; }
env_url() {
  case "$1" in
    development) printf '%s' 'https://fabushi-flutter-web-dev.bhrumom.workers.dev' ;;
    production) printf '%s' 'https://api.ombhrum.com' ;;
    *) return 1 ;;
  esac
}
mail_candidate() {
  local names="$1"
  contains_name "$names" AUTH_SYSTEM_MAIL_URL \
    && contains_name "$names" AUTH_SYSTEM_MAIL_TOKEN \
    && contains_name "$names" AUTH_SYSTEM_MAIL_ENABLED
}

printf '%s\n' 'Inspecting legacy Worker secret names only; secret values are never read.'
dev_names="$(secret_names development)"
prod_names="$(secret_names production)"
dev_alipay=false; prod_alipay=false
dev_mail=false; prod_mail=false
contains_name "$dev_names" ALIPAY_PRIVATE_KEY && dev_alipay=true || true
contains_name "$prod_names" ALIPAY_PRIVATE_KEY && prod_alipay=true || true
mail_candidate "$dev_names" && dev_mail=true || true
mail_candidate "$prod_names" && prod_mail=true || true
printf 'Legacy candidates: development(Alipay=%s,self-hosted-mail=%s) production(Alipay=%s,self-hosted-mail=%s)\n' \
  "$dev_alipay" "$dev_mail" "$prod_alipay" "$prod_mail"

if [[ "$dev_alipay" == true ]]; then alipay_env=development
elif [[ "$prod_alipay" == true ]]; then alipay_env=production
else echo 'No deployed legacy Worker has ALIPAY_PRIVATE_KEY; refusing fake Alipay rollout.' >&2; exit 21
fi
alipay_url="$(env_url "$alipay_env")"

bridge_secret="$(openssl rand -base64 48 | tr -d '\n')"
echo "::add-mask::$bridge_secret"

# Configure the proof on every deployed legacy Worker that may serve either
# identity exchange or self-hosted system mail. Capability probing below decides
# which mail environment is actually enabled at runtime.
for environment in development production; do
  names="$dev_names"; alipay="$dev_alipay"; mail="$dev_mail"
  [[ "$environment" == production ]] && { names="$prod_names"; alipay="$prod_alipay"; mail="$prod_mail"; }
  if [[ "$alipay" == true || "$mail" == true ]]; then
    (
      cd "$LEGACY_DIR"
      printf '%s' "$bridge_secret" | npx --yes "wrangler@${WRANGLER_VERSION}" secret put AUTH_PROVIDER_BRIDGE_SECRET --env "$environment" >/dev/null
      printf '%s' "$PLATFORM_URL" | npx --yes "wrangler@${WRANGLER_VERSION}" secret put AUTH_PROVIDER_BRIDGE_RETURN_BASE --env "$environment" >/dev/null
    )
  fi
done

alipay_caps="$(curl --fail --silent --show-error --retry 8 --retry-all-errors --retry-delay 3 \
  -H "X-Fabushi-Auth-Bridge: $bridge_secret" \
  "$alipay_url/api/internal/auth-provider/capabilities")"
jq -e '.ok == true and .alipay == true' <<<"$alipay_caps" >/dev/null

email_env=''
email_url=''
email_ready=false
for environment in development production; do
  candidate="$dev_mail"
  [[ "$environment" == production ]] && candidate="$prod_mail"
  [[ "$candidate" == true ]] || continue
  url="$(env_url "$environment")"
  caps="$(curl --silent --show-error --retry 4 --retry-all-errors --retry-delay 2 \
    -H "X-Fabushi-Auth-Bridge: $bridge_secret" \
    "$url/api/internal/auth-provider/capabilities" || true)"
  if jq -e '.ok == true and .email == true' <<<"$caps" >/dev/null 2>&1; then
    email_env="$environment"
    email_url="$url"
    email_ready=true
    break
  fi
done
printf 'Selected deployed identity bridges: Alipay=%s email=%s\n' "$alipay_env" "${email_env:-unavailable}"

(
  cd "$PLATFORM_DIR"
  printf '%s' "$bridge_secret" | npx --yes "wrangler@${WRANGLER_VERSION}" secret put AUTH_PROVIDER_BRIDGE_SECRET >/dev/null
  printf '%s' "$alipay_url" | npx --yes "wrangler@${WRANGLER_VERSION}" secret put AUTH_PROVIDER_BRIDGE_URL >/dev/null
  if [[ "$email_ready" == true ]]; then
    printf '%s' "$email_url" | npx --yes "wrangler@${WRANGLER_VERSION}" secret put AUTH_REGISTRATION_BRIDGE_URL >/dev/null
  else
    npx --yes "wrangler@${WRANGLER_VERSION}" secret delete AUTH_REGISTRATION_BRIDGE_URL >/dev/null 2>&1 || true
  fi
)

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "bridge_env=$alipay_env"
    echo "bridge_url=$alipay_url"
    echo "email_bridge_env=${email_env:-}"
    echo "email_bridge_url=$email_url"
    echo "alipay_ready=true"
    echo "email_ready=$email_ready"
  } >>"$GITHUB_OUTPUT"
fi
printf 'Identity bridge proof configured: Alipay=%s registration-email=%s\n' "$alipay_url" "${email_url:-unavailable}"
