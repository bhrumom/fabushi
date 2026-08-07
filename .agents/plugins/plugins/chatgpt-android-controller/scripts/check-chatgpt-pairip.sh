#!/usr/bin/env bash
set -euo pipefail

archive="${1:?usage: check-chatgpt-pairip.sh <xapk>}"
sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
aapt_bin=$(find "$sdk_root/build-tools" -type f -name aapt -perm -u+x -print 2>/dev/null | sort -V | tail -n 1)
if [[ -z "$aapt_bin" ]]; then
  echo 'Android aapt is required to inspect the ChatGPT package.' >&2
  exit 1
fi

test -s "$archive"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
unzip -q "$archive" -d "$work"

pairip=false
while IFS= read -r apk; do
  if "$aapt_bin" dump xmltree "$apk" AndroidManifest.xml 2>/dev/null \
      | grep -qiE 'com\.pairip|pairip\.licensecheck|LicenseActivity'; then
    echo "PairIP manifest evidence: $(basename "$apk")"
    pairip=true
  fi
  if unzip -Z1 "$apk" 2>/dev/null | grep -qiE '(^|/)libpairip[^/]*\.so$|pairip'; then
    echo "PairIP archive evidence: $(basename "$apk")"
    pairip=true
  fi
done < <(find "$work" -type f -name '*.apk' -print | sort)

if [[ "$pairip" == true ]]; then
  echo 'pairip=true'
  exit 2
fi

echo 'pairip=false'
