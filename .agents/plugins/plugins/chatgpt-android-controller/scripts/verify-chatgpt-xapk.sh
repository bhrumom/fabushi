#!/usr/bin/env bash
set -euo pipefail

archive="${1:?usage: verify-chatgpt-xapk.sh <xapk>}"
expected_package="${CHATGPT_ANDROID_PACKAGE:-com.openai.chatgpt}"
expected_cert="${CHATGPT_ANDROID_CERT_SHA256:-b24f4bfbb3cf293f938703b9d87027c1102cc36dc4fa206910e08927db40473c}"
sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"

test -s "$archive"
unzip -tqq "$archive"

apksigner_bin=$(find "$sdk_root/build-tools" -type f -name apksigner -perm -u+x -print 2>/dev/null | sort -V | tail -n 1)
aapt_bin=$(find "$sdk_root/build-tools" -type f -name aapt -perm -u+x -print 2>/dev/null | sort -V | tail -n 1)
if [[ -z "$apksigner_bin" || -z "$aapt_bin" ]]; then
  echo "Android build-tools are required under $sdk_root/build-tools." >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
unzip -q "$archive" -d "$work"
mapfile -t apks < <(find "$work" -type f -name '*.apk' -print | sort)
if (( ${#apks[@]} == 0 )); then
  echo 'XAPK contains no APK files.' >&2
  exit 1
fi

base_count=0
x86_64_evidence=0
for apk in "${apks[@]}"; do
  cert=$("$apksigner_bin" verify --print-certs "$apk" 2>/dev/null \
    | sed -n 's/^Signer #1 certificate SHA-256 digest: //p' \
    | head -n 1 \
    | tr '[:upper:]' '[:lower:]' \
    | tr -d ':[:space:]')
  if [[ -z "$cert" || "$cert" != "${expected_cert,,}" ]]; then
    echo "Unexpected signing certificate in $(basename "$apk"): ${cert:-missing}" >&2
    exit 1
  fi

  badging=$("$aapt_bin" dump badging "$apk" 2>/dev/null || true)
  package=$(printf '%s\n' "$badging" | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -n 1)
  if [[ "$package" != "$expected_package" ]]; then
    echo "Unexpected package in $(basename "$apk"): ${package:-missing}" >&2
    exit 1
  fi

  first_line=$(printf '%s\n' "$badging" | head -n 1)
  if [[ "$first_line" != *" split='"* ]]; then
    base_count=$((base_count + 1))
  fi

  if [[ "$(basename "$apk")" == *x86_64* ]] \
      || unzip -Z1 "$apk" 2>/dev/null | grep -q '^lib/x86_64/'; then
    x86_64_evidence=$((x86_64_evidence + 1))
  fi
done

if (( base_count != 1 )); then
  echo "Expected exactly one base APK, found $base_count." >&2
  exit 1
fi
if (( x86_64_evidence == 0 )); then
  echo 'Verified package has no x86_64 split/native-library evidence.' >&2
  exit 1
fi

printf 'Verified ChatGPT XAPK package=%s apk_count=%d cert_sha256=%s x86_64_evidence=%d\n' \
  "$expected_package" "${#apks[@]}" "${expected_cert,,}" "$x86_64_evidence"
