#!/usr/bin/env bash
set -euo pipefail

page_url="${CHATGPT_APKCOMBO_PAGE_URL:-https://apkcombo.com/chatgpt/com.openai.chatgpt/download/apk}"
version_name="${CHATGPT_ANDROID_VERSION_NAME:-1.2026.202}"
version_code="${CHATGPT_ANDROID_VERSION_CODE:-2620225}"
output="${1:-${RUNNER_TEMP:-/tmp}/chatgpt-${version_name}.xapk}"
page="$(mktemp)"
trap 'rm -f "$page"' EXIT

curl --fail --location --silent --show-error --retry 3 \
  --user-agent 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/139 Safari/537.36' \
  --header 'Accept-Language: en-US,en;q=0.9' \
  "$page_url" --output "$page"

download_url="$({
  python3 - "$page" "$version_name" "$version_code" <<'PY'
from __future__ import annotations

import html
import re
import sys
from pathlib import Path
from urllib.parse import parse_qs, urljoin, urlparse

page = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
version_name = sys.argv[2]
version_code = sys.argv[3]

hrefs = re.findall(r'''href=["']([^"']+)["']''', page, flags=re.I)
candidates: list[tuple[int, str]] = []
for raw in hrefs:
    href = html.unescape(raw)
    if "/r2?u=" not in href:
        continue
    absolute = urljoin("https://apkcombo.com", href)
    parsed = urlparse(absolute)
    target = parse_qs(parsed.query).get("u", [""])[0]
    score = 0
    haystack = f"{absolute} {target}"
    if "com.openai.chatgpt" in haystack:
        score += 4
    if version_name in haystack:
        score += 4
    if version_code in haystack:
        score += 8
    candidates.append((score, absolute))

if not candidates:
    raise SystemExit("APKCombo page did not expose any /r2 download links")

candidates.sort(key=lambda item: item[0], reverse=True)
best_score, best_url = candidates[0]
if best_score < 4:
    raise SystemExit("APKCombo download candidates did not match com.openai.chatgpt")
print(best_url)
PY
} | tail -n 1)"

if [[ -z "$download_url" ]]; then
  echo 'Unable to resolve an APKCombo download URL.' >&2
  exit 1
fi

# The /r2 URL contains a short-lived storage signature. Do not print it.
curl --fail --location --silent --show-error --retry 3 \
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
