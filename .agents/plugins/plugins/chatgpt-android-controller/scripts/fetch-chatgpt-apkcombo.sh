#!/usr/bin/env bash
set -euo pipefail

page_url="${CHATGPT_APKCOMBO_PAGE_URL:-https://apkcombo.com/chatgpt/com.openai.chatgpt/download/apk}"
requested_version="${CHATGPT_ANDROID_VERSION_NAME:-}"
requested_code="${CHATGPT_ANDROID_VERSION_CODE:-}"
output="${1:-${RUNNER_TEMP:-/tmp}/chatgpt-latest.xapk}"
page="$(mktemp)"
meta="$(mktemp)"
trap 'rm -f "$page" "$meta"' EXIT

curl --fail --location --silent --show-error --retry 3 \
  --connect-timeout 30 --max-time 120 \
  --user-agent 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/139 Safari/537.36' \
  --header 'Accept-Language: en-US,en;q=0.9' \
  "$page_url" --output "$page"

python3 - "$page" "$requested_version" "$requested_code" >"$meta" <<'PY'
from __future__ import annotations

import html
import re
import sys
from pathlib import Path
from urllib.parse import parse_qs, unquote, urljoin, urlparse

page = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
requested_version = sys.argv[2].strip()
requested_code = sys.argv[3].strip()

hrefs = re.findall(r'''href=["']([^"']+)["']''', page, flags=re.I)
candidates: list[tuple[int, str, str, str]] = []
for raw in hrefs:
    href = html.unescape(raw)
    if "/r2?u=" not in href:
        continue
    absolute = urljoin("https://apkcombo.com", href)
    parsed = urlparse(absolute)
    target = unquote(parse_qs(parsed.query).get("u", [""])[0])
    if "com.openai.chatgpt" not in target:
        continue
    match = re.search(r"/com\.openai\.chatgpt/([^/]+)/([0-9]+)[^/]*\.apks(?:\?|$)", target)
    if not match:
        continue
    version_name, version_code = match.group(1), match.group(2)
    if requested_version and version_name != requested_version:
        continue
    if requested_code and version_code != requested_code:
        continue
    candidates.append((int(version_code), version_name, version_code, absolute))

if not candidates:
    extra = ""
    if requested_version or requested_code:
        extra = f" for requested version={requested_version or '*'} code={requested_code or '*'}"
    raise SystemExit(f"APKCombo page exposed no ChatGPT XAPK download candidate{extra}")

candidates.sort(key=lambda item: item[0], reverse=True)
_, version_name, version_code, download_url = candidates[0]
print(version_name)
print(version_code)
print(download_url)
PY

version_name=$(sed -n '1p' "$meta")
version_code=$(sed -n '2p' "$meta")
download_url=$(sed -n '3p' "$meta")
if [[ -z "$version_name" || -z "$version_code" || -z "$download_url" ]]; then
  echo 'Unable to resolve a complete APKCombo download candidate.' >&2
  exit 1
fi

# The /r2 URL contains a short-lived Cloudflare R2 signature. Never print it.
curl --fail --location --silent --show-error --retry 3 \
  --connect-timeout 30 --max-time 300 \
  --user-agent 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/139 Safari/537.36' \
  "$download_url" --output "$output"

test -s "$output"
unzip -tqq "$output"
if ! unzip -Z1 "$output" | grep -Eq '\.apk$'; then
  echo 'Downloaded APKCombo archive contains no APK files.' >&2
  exit 1
fi

bytes=$(wc -c < "$output" | tr -d ' ')
sha256=$(sha256sum "$output" | awk '{print $1}')
printf 'Downloaded ChatGPT XAPK version=%s code=%s bytes=%s sha256=%s\n' \
  "$version_name" "$version_code" "$bytes" "$sha256"
