#!/usr/bin/env bash
set -euo pipefail

version_name="${CHATGPT_ANDROID_VERSION_NAME:-1.2024.324}"
version_code="${CHATGPT_ANDROID_VERSION_CODE:-439}"
output="${1:-${RUNNER_TEMP:-/tmp}/chatgpt-${version_name}.xapk}"
page_url="https://apkpure.net/chatgpt/com.openai.chatgpt/download/${version_name}"
ua='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/139 Safari/537.36'
page=$(mktemp)
cookies=$(mktemp)
headers=$(mktemp)
trap 'rm -f "$page" "$cookies" "$headers"' EXIT

# APKPure's CDN rejects some datacenter requests that jump straight to the
# binary endpoint. Establish the same first-party page session a browser uses,
# then follow the page's exact versionCode download link with its cookies and
# referer. The downloaded APKs are still independently verified afterwards.
curl --fail --location --silent --show-error --retry 3 --retry-all-errors \
  --connect-timeout 20 --max-time 90 \
  --user-agent "$ua" \
  --header 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
  --header 'Accept-Language: en-US,en;q=0.9' \
  --cookie-jar "$cookies" \
  "$page_url" --output "$page"

download_url=$(python3 - "$page" "$version_code" <<'PY'
from __future__ import annotations
import html
import re
import sys
from pathlib import Path
from urllib.parse import urljoin

page = Path(sys.argv[1]).read_text(encoding='utf-8', errors='replace')
code = sys.argv[2]
links = [html.unescape(x) for x in re.findall(r'''href\s*=\s*["']([^"']+)["']''', page, flags=re.I)]
for href in links:
    if 'd.apkpure.net/' not in href:
        continue
    if 'com.openai.chatgpt' not in href:
        continue
    if f'versionCode={code}' not in href:
        continue
    print(urljoin('https://apkpure.net', href))
    break
else:
    raise SystemExit(f'APKPure version page exposed no ChatGPT download link for versionCode={code}')
PY
)

if [[ -z "$download_url" ]]; then
  echo "Failed to resolve APKPure download URL for $version_name ($version_code)." >&2
  exit 1
fi

set +e
curl --location --silent --show-error --retry 3 --retry-all-errors \
  --connect-timeout 20 --max-time 300 \
  --user-agent "$ua" \
  --header 'Accept: application/octet-stream,application/vnd.android.package-archive,*/*;q=0.8' \
  --header 'Accept-Language: en-US,en;q=0.9' \
  --header 'Sec-Fetch-Dest: document' \
  --header 'Sec-Fetch-Mode: navigate' \
  --header 'Sec-Fetch-Site: same-site' \
  --referer "$page_url" \
  --cookie "$cookies" \
  --dump-header "$headers" \
  --write-out '%{http_code}' \
  "$download_url" --output "$output" >"${headers}.status"
status=$?
http_code=$(cat "${headers}.status" 2>/dev/null || true)
rm -f "${headers}.status"
set -e

if (( status != 0 )) || [[ ! "$http_code" =~ ^2 ]]; then
  echo "APKPure binary request failed: curl_status=$status http_status=${http_code:-unknown}" >&2
  # Keep diagnostics non-sensitive: only response status/server/location host,
  # never the tokenized redirected URL query string.
  awk 'BEGIN{IGNORECASE=1} /^HTTP\// {print} /^server:/ {print} /^location:/ {
      sub(/^location:[[:space:]]*/, "", $0); split($0, a, "/"); print "location-host=" a[3]
    }' "$headers" >&2 || true
  exit 1
fi

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
