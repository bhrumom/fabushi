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
has_email_binding() {
  local environment="$1"
  python3 - "$LEGACY_DIR/wrangler.toml" "$environment" <<'PYTOML'
import sys
import tomllib
with open(sys.argv[1], 'rb') as handle:
    config = tomllib.load(handle)
environment = sys.argv[2]
bindings = config.get('env', {}).get(environment, {}).get('send_email', [])
print('true' if any(binding.get('name') == 'EMAIL' for binding in bindings) else 'false')
PYTOML
}
email_sending_dns_ready() {
  local mx spf dkim
  mx="$(curl --fail --silent --show-error -H 'accept: application/dns-json' --get --data-urlencode 'name=cf-bounce.ombhrum.com' --data-urlencode 'type=MX' 'https://cloudflare-dns.com/dns-query')"
  spf="$(curl --fail --silent --show-error -H 'accept: application/dns-json' --get --data-urlencode 'name=cf-bounce.ombhrum.com' --data-urlencode 'type=TXT' 'https://cloudflare-dns.com/dns-query')"
  dkim="$(curl --fail --silent --show-error -H 'accept: application/dns-json' --get --data-urlencode 'name=cf-bounce._domainkey.ombhrum.com' --data-urlencode 'type=TXT' 'https://cloudflare-dns.com/dns-query')"
  jq -e '.Status == 0 and any(.Answer[]?; (.data // "") | test("mx\.cloudflare\.net"; "i"))' <<<"$mx" >/dev/null     && jq -e '.Status == 0 and any(.Answer[]?; (.data // "") | contains("include:_spf.mx.cloudflare.net"))' <<<"$spf" >/dev/null     && jq -e '.Status == 0 and any(.Answer[]?; (.data // "") | contains("v=DKIM1"))' <<<"$dkim" >/dev/null
}
env_url() {
  case "$1" in
    development) printf '%s' 'https://fabushi-flutter-web-dev.bhrumom.workers.dev' ;;
    production) printf '%s' 'https://api.ombhrum.com' ;;
    *) return 1 ;;
  esac
}

printf '%s\n' 'Inspecting legacy Worker secret names only; secret values are never read.'
dev_names="$(secret_names development)"
prod_names="$(secret_names production)"
dev_alipay=false; prod_alipay=false
dev_binding="$(has_email_binding development)"
prod_binding="$(has_email_binding production)"
dev_resend=false; prod_resend=false
contains_name "$dev_names" ALIPAY_PRIVATE_KEY && dev_alipay=true || true
contains_name "$dev_names" RESEND_API_KEY && dev_resend=true || true
contains_name "$prod_names" ALIPAY_PRIVATE_KEY && prod_alipay=true || true
contains_name "$prod_names" RESEND_API_KEY && prod_resend=true || true
sending_dns_ready=false
email_sending_dns_ready && sending_dns_ready=true || true
dev_email=false; prod_email=false
[[ "$dev_resend" == true || ("$dev_binding" == true && "$sending_dns_ready" == true) ]] && dev_email=true || true
[[ "$prod_resend" == true || ("$prod_binding" == true && "$sending_dns_ready" == true) ]] && prod_email=true || true
printf 'Legacy capabilities: development(Alipay=%s,email-binding=%s,Resend=%s) production(Alipay=%s,email-binding=%s,Resend=%s) sending-dns=%s\n' "$dev_alipay" "$dev_binding" "$dev_resend" "$prod_alipay" "$prod_binding" "$prod_resend" "$sending_dns_ready"

if [[ "$dev_alipay" == true ]]; then alipay_env=development
elif [[ "$prod_alipay" == true ]]; then alipay_env=production
else echo 'No deployed legacy Worker has ALIPAY_PRIVATE_KEY; refusing fake Alipay rollout.' >&2; exit 21
fi
if [[ "$dev_email" == true ]]; then email_env=development
elif [[ "$prod_email" == true ]]; then email_env=production
else email_env=''
fi

alipay_url="$(env_url "$alipay_env")"
email_url=''
email_ready=false
if [[ -n "$email_env" ]]; then email_url="$(env_url "$email_env")"; email_ready=true; fi
printf 'Selected deployed identity bridges: Alipay=%s email=%s\n' "$alipay_env" "${email_env:-unavailable}"

bridge_secret="$(openssl rand -base64 48 | tr -d '\n')"
echo "::add-mask::$bridge_secret"

selected_envs=("$alipay_env")
if [[ -n "$email_env" && "$email_env" != "$alipay_env" ]]; then selected_envs+=("$email_env"); fi
for environment in "${selected_envs[@]}"; do
  (
    cd "$LEGACY_DIR"
    printf '%s' "$bridge_secret" | npx --yes "wrangler@${WRANGLER_VERSION}" secret put AUTH_PROVIDER_BRIDGE_SECRET --env "$environment" >/dev/null
    printf '%s' "$PLATFORM_URL" | npx --yes "wrangler@${WRANGLER_VERSION}" secret put AUTH_PROVIDER_BRIDGE_RETURN_BASE --env "$environment" >/dev/null
  )
done
for environment in development production; do
  binding="$(has_email_binding "$environment")"
  names="$dev_names"; ready="$dev_email"
  [[ "$environment" == production ]] && { names="$prod_names"; ready="$prod_email"; }
  if [[ "$binding" == true ]] || contains_name "$names" RESEND_API_KEY; then
    (cd "$LEGACY_DIR" && printf '%s' "$ready" | npx --yes "wrangler@${WRANGLER_VERSION}" secret put AUTH_REGISTRATION_EMAIL_READY --env "$environment" >/dev/null)
  fi
done
(
  cd "$PLATFORM_DIR"
  printf '%s' "$bridge_secret" | npx --yes "wrangler@${WRANGLER_VERSION}" secret put AUTH_PROVIDER_BRIDGE_SECRET >/dev/null
  printf '%s' "$alipay_url" | npx --yes "wrangler@${WRANGLER_VERSION}" secret put AUTH_PROVIDER_BRIDGE_URL >/dev/null
  if [[ -n "$email_url" ]]; then
    printf '%s' "$email_url" | npx --yes "wrangler@${WRANGLER_VERSION}" secret put AUTH_REGISTRATION_BRIDGE_URL >/dev/null
  else
    npx --yes "wrangler@${WRANGLER_VERSION}" secret delete AUTH_REGISTRATION_BRIDGE_URL >/dev/null 2>&1 || true
  fi
)

alipay_caps="$(curl --fail --silent --show-error --retry 8 --retry-all-errors --retry-delay 3 -H "X-Fabushi-Auth-Bridge: $bridge_secret" "$alipay_url/api/internal/auth-provider/capabilities")"
jq -e '.ok == true and .alipay == true' <<<"$alipay_caps" >/dev/null
if [[ "$email_ready" == true ]]; then
  email_caps="$(curl --fail --silent --show-error --retry 8 --retry-all-errors --retry-delay 3 -H "X-Fabushi-Auth-Bridge: $bridge_secret" "$email_url/api/internal/auth-provider/capabilities")"
  jq -e '.ok == true and .email == true' <<<"$email_caps" >/dev/null
fi

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
