#!/usr/bin/env bash
set -euo pipefail

version_name="${CHATGPT_ANDROID_VERSION_NAME:-1.2026.027}"
version_code="${CHATGPT_ANDROID_VERSION_CODE:-2602719}"
output="${1:-${RUNNER_TEMP:-/tmp}/chatgpt-${version_name}.xapk}"
url="https://d.apkpure.net/b/XAPK/com.openai.chatgpt?versionCode=${version_code}"

curl --fail --location --silent --show-error --retry 3 \
  --retry-all-errors --connect-timeout 20 --max-time 240 \
  --user-agent 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/139 Safari/537.36' \
  --header 'Accept: application/octet-stream,*/*;q=0.8' \
  "$url" --output "$output"

test -s "$output"
unzip -tqq "$output"
if ! unzip -Z1 "$output" | grep -Eq '\.apk$'; then
  echo 'Downloaded APKPure archive contains no APK files.' >&2
  exit 1
fi

bytes=$(wc -c < "$output" | tr -d ' ')
sha256=$(sha256sum "$output" | awk '{print $1}')
printf 'Downloaded ChatGPT XAPK source=APKPure version=%s code=%s bytes=%s sha256=%s\n' \
  "$version_name" "$version_code" "$bytes" "$sha256"
