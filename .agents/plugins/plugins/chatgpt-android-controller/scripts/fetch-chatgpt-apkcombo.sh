#!/usr/bin/env bash
set -euo pipefail

version_name="${CHATGPT_ANDROID_VERSION_NAME:-1.2026.216}"
version_code="${CHATGPT_ANDROID_VERSION_CODE:-2621621}"
page_url="${CHATGPT_APKCOMBO_PAGE_URL:-https://apkcombo.com/chatgpt/com.openai.chatgpt/download/apk}"
output="${1:-${RUNNER_TEMP:-/tmp}/chatgpt-${version_name}.xapk}"
page="$(mktemp)"
meta="$(mktemp)"
profile="$(mktemp -d)"
trap 'rm -f "$page" "$meta"; rm -rf "$profile"' EXIT

ua='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36'

fetch_page_with_curl() {
  curl --fail --location --silent --show-error --retry 2 --retry-all-errors \
    --connect-timeout 20 --max-time 90 \
    --user-agent "$ua" \
    --header 'Accept-Language: en-US,en;q=0.9' \
    --header 'Cache-Control: no-cache' \
    --header 'Pragma: no-cache' \
    "$page_url" --output "$page"
}

fetch_page_with_chrome() {
  local chrome=''
  for candidate in google-chrome google-chrome-stable chromium chromium-browser; do
    if command -v "$candidate" >/dev/null 2>&1; then
      chrome=$(command -v "$candidate")
      break
    fi
  done
  if [[ -z "$chrome" ]]; then
    echo 'APKCombo blocked curl and no Chrome/Chromium executable is available.' >&2
    return 1
  fi
  echo "APKCombo curl access was blocked; resolving the public download page with $(basename "$chrome") headless."
  "$chrome" \
    --headless=new \
    --no-sandbox \
    --disable-gpu \
    --disable-dev-shm-usage \
    --disable-background-networking \
    --disable-component-update \
    --disable-default-apps \
    --disable-extensions \
    --disable-sync \
    --no-first-run \
    --user-data-dir="$profile" \
    --user-agent="$ua" \
    --virtual-time-budget=8000 \
    --dump-dom "$page_url" >"$page"
  test -s "$page"
}

if ! fetch_page_with_curl; then
  : >"$page"
  fetch_page_with_chrome
fi

python3 - "$page" "$version_name" "$version_code" >"$meta" <<'PY'
from __future__ import annotations

import html
import re
import sys
from pathlib import Path
from urllib.parse import parse_qs, unquote, urljoin, urlparse

page = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
version_name = sys.argv[2]
version_code = sys.argv[3]

hrefs = re.findall(r'''href\s*=\s*["']([^"']+)["']''', page, flags=re.I)
candidates: list[tuple[str, str]] = []
for raw in hrefs:
    href = html.unescape(raw)
    if "/r2?" not in href:
        continue
    wrapper = urljoin("https://apkcombo.com", href)
    parsed = urlparse(wrapper)
    target = unquote(parse_qs(parsed.query).get("u", [""])[0])
    if not target:
        continue
    target_parsed = urlparse(target)
    host = target_parsed.hostname or ""
    path = target_parsed.path
    if not host.endswith(".r2.cloudflarestorage.com"):
        continue
    if "/com.openai.chatgpt/" not in path:
        continue
    if f"/{version_name}/" not in path:
        continue
    if not re.search(rf"/{re.escape(version_code)}(?:\.|/)", path):
        continue
    if not path.endswith(".apks"):
        continue
    candidates.append((wrapper, target))

if not candidates:
    title = re.search(r"<title[^>]*>(.*?)</title>", page, flags=re.I | re.S)
    title_text = re.sub(r"\s+", " ", html.unescape(title.group(1))).strip() if title else "missing"
    raise SystemExit(
        f"APKCombo page exposed no matching R2 ChatGPT link for version={version_name} code={version_code}; title={title_text}"
    )

wrapper, target = candidates[-1]
print(wrapper)
print(target)
PY

wrapper_url=$(sed -n '1p' "$meta")
download_url=$(sed -n '2p' "$meta")
if [[ -z "$wrapper_url" || -z "$download_url" ]]; then
  echo 'Failed to resolve a fresh APKCombo R2 URL.' >&2
  exit 1
fi

# The target contains short-lived AWS query credentials. Never echo either URL.
curl --fail --location --silent --show-error --retry 4 --retry-all-errors \
  --connect-timeout 20 --max-time 360 \
  --user-agent "$ua" \
  --referer "$page_url" \
  "$download_url" --output "$output"

test -s "$output"
unzip -tqq "$output"
if ! unzip -Z1 "$output" | grep -Eq '\.apk$'; then
  echo 'Downloaded APKCombo archive contains no APK files.' >&2
  exit 1
fi

bytes=$(wc -c < "$output" | tr -d ' ')
sha256=$(sha256sum "$output" | awk '{print $1}')
printf 'Downloaded ChatGPT XAPK source=APKCombo version=%s code=%s bytes=%s sha256=%s\n' \
  "$version_name" "$version_code" "$bytes" "$sha256"
