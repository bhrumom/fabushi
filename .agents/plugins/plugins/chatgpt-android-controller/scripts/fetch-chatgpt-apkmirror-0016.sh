#!/usr/bin/env bash
set -euo pipefail

output="${1:-${RUNNER_TEMP:-/tmp}/chatgpt-1.0.0016.apkm}"
page_url='https://www.apkmirror.com/apk/openai/chatgpt/chatgpt-9-1-0-0016-release/chatgpt-1-0-0016-android-apk-download/'
expected_sha256='fe9e6f4b68b79d69c27a1c4508023e90a2a6efa0126b3cae8cb0f98c9a80c5ab'
ua='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/139 Safari/537.36'
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

current="$page_url"
for attempt in 1 2 3 4; do
  body="$work/body-$attempt"
  headers="$work/headers-$attempt"
  curl --fail --location --silent --show-error --retry 2 \
    --connect-timeout 20 --max-time 180 \
    --user-agent "$ua" \
    --header 'Accept-Language: en-US,en;q=0.9' \
    --dump-header "$headers" \
    "$current" --output "$body"

  if unzip -tqq "$body" >/dev/null 2>&1; then
    cp "$body" "$output"
    break
  fi

  next=$(python3 - "$body" "$current" <<'PY'
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin
import sys

class Parser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links=[]
    def handle_starttag(self, tag, attrs):
        if tag.lower() != 'a':
            return
        d=dict(attrs)
        href=d.get('href','')
        cls=d.get('class','')
        if not href:
            return
        score=0
        if 'downloadButton' in cls:
            score += 20
        if '/wp-content/themes/APKMirror/download.php' in href:
            score += 15
        if 'downloadr2.apkmirror.com' in href:
            score += 30
        if 'key=' in href and 'download' in href.lower():
            score += 10
        if score:
            self.links.append((score, href))

p=Parser()
p.feed(Path(sys.argv[1]).read_text(encoding='utf-8', errors='replace'))
if not p.links:
    raise SystemExit(1)
p.links.sort(key=lambda x:x[0], reverse=True)
print(urljoin(sys.argv[2], p.links[0][1]))
PY
  ) || {
    echo "APKMirror download page did not expose a usable download link at stage $attempt." >&2
    grep -Eoi 'Why Can.t I Download|Download APK Bundle|downloadButton|download\.php' "$body" | head -n 20 >&2 || true
    exit 1
  }
  current="$next"
done

if [[ ! -s "$output" ]]; then
  echo 'APKMirror download flow did not yield the APK bundle.' >&2
  exit 1
fi

actual=$(sha256sum "$output" | awk '{print tolower($1)}')
if [[ "$actual" != "$expected_sha256" ]]; then
  echo "APKMirror ChatGPT 1.0.0016 SHA-256 mismatch: $actual" >&2
  exit 1
fi
unzip -tqq "$output"
printf 'Downloaded verified APKMirror ChatGPT 1.0.0016 bundle bytes=%s sha256=%s\n' \
  "$(wc -c < "$output" | tr -d ' ')" "$actual"
