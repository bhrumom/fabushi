#!/usr/bin/env bash
set -euo pipefail

account_id="${CHATGPT_ACCOUNT_ID:-}"
state_key="${CHATGPT_AUTO_CONFIRM_STATE_KEY:-}"
repo="${GITHUB_REPOSITORY:-bhrumom/fabushi}"
github_env="${GITHUB_ENV:-}"
runtime_root="${RUNNER_TEMP:-/tmp}/chatgpt-android-account-credential"

if [[ ! "$account_id" =~ ^acct_[0-9a-f]{12}$ ]]; then
  echo "::error::CHATGPT_ACCOUNT_ID is not a valid account scope: $account_id"
  exit 1
fi
if [[ -z "$state_key" ]]; then
  echo '::error::Account state key is unavailable.'
  exit 1
fi
if [[ -z "${GH_TOKEN:-}" ]]; then
  echo '::error::GH_TOKEN is unavailable for account credential artifact lookup.'
  exit 1
fi
if [[ -z "$github_env" ]]; then
  echo '::error::GITHUB_ENV is unavailable.'
  exit 1
fi

repo_root=$(git rev-parse --show-toplevel)
unpack_script="$repo_root/.agents/plugins/plugins/chatgpt-auto-confirm/scripts/credential-bundle.mjs"
test -f "$unpack_script"

rm -rf "$runtime_root"
mkdir -p "$runtime_root/unpacked"
chmod 700 "$runtime_root" "$runtime_root/unpacked"

artifact_name="chatgpt-auto-confirm-credentials-$account_id"
artifact_id=$(gh api --paginate "/repos/$repo/actions/artifacts?name=$artifact_name&per_page=100" \
  --jq '[.artifacts[] | select(.expired == false)] | sort_by(.created_at) | last // empty | .id')
if [[ -z "$artifact_id" ]]; then
  echo "::error::No non-expired rolling credential bundle exists for $account_id."
  exit 1
fi

zip_path="$runtime_root/bundle.zip"
gh api "/repos/$repo/actions/artifacts/$artifact_id/zip" > "$zip_path"
test -s "$zip_path"
unzip -q "$zip_path" -d "$runtime_root/unpacked"
bundle=$(find "$runtime_root/unpacked" -type f -name '*.enc.json' -print -quit)
if [[ -z "$bundle" ]]; then
  echo '::error::Downloaded credential artifact contains no encrypted credential bundle.'
  exit 1
fi

auth_path="$runtime_root/auth.json"
cookies_path="$runtime_root/cookies.json"
node "$unpack_script" unpack \
  --account-id "$account_id" \
  --state-key "$state_key" \
  --input "$bundle" \
  --auth-output "$auth_path" \
  --cookies-output "$cookies_path"
test -s "$auth_path"
test -s "$cookies_path"
chmod 600 "$auth_path" "$cookies_path"

auth_b64=$(base64 < "$auth_path" | tr -d '\r\n')
cookies_b64=$(base64 < "$cookies_path" | tr -d '\r\n')
if [[ -z "$auth_b64" || -z "$cookies_b64" ]]; then
  echo '::error::Restored account credential payload is empty.'
  exit 1
fi
printf '::add-mask::%s\n' "$auth_b64"
printf '::add-mask::%s\n' "$cookies_b64"
printf 'CHATGPT_CODEX_AUTH_B64=%s\n' "$auth_b64" >> "$github_env"
printf 'CHATGPT_SESSION_COOKIES_B64=%s\n' "$cookies_b64" >> "$github_env"

# Do not print credential contents or identifiers derived from them. The
# artifact id is safe and useful to prove that the newest rolling bundle was
# selected for this run.
echo "Restored rolling account credential bundle artifact_id=$artifact_id account_id=$account_id"
rm -f "$auth_path" "$cookies_path" "$zip_path"
