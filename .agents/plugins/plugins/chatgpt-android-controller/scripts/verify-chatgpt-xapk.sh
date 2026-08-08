#!/usr/bin/env bash
set -euo pipefail

archive="${1:?usage: verify-chatgpt-xapk.sh <xapk>}"
expected_package="${CHATGPT_ANDROID_PACKAGE:-com.openai.chatgpt}"
expected_cert="${CHATGPT_ANDROID_CERT_SHA256:-b24f4bfbb3cf293f938703b9d87027c1102cc36dc4fa206910e08927db40473c}"
expected_version_name="${CHATGPT_ANDROID_VERSION_NAME:-}"
expected_version_code="${CHATGPT_ANDROID_VERSION_CODE:-}"
require_x86_64="${CHATGPT_ANDROID_REQUIRE_X86_64:-true}"
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
verified_version_name=''
verified_version_code=''
for apk in "${apks[@]}"; do
  signer_output=$("$apksigner_bin" verify --print-certs "$apk" 2>&1) || {
    echo "apksigner rejected $(basename "$apk")." >&2
    printf '%s\n' "$signer_output" | tail -n 20 >&2
    exit 1
  }
  cert_line=$(printf '%s\n' "$signer_output" | grep -im1 'certificate SHA-256 digest' || true)
  cert=$(printf '%s\n' "$cert_line" \
    | grep -Eo '[0-9A-Fa-f]{64}' \
    | head -n 1 \
    | tr '[:upper:]' '[:lower:]' || true)
  if [[ -z "$cert" || "$cert" != "${expected_cert,,}" ]]; then
    echo "Unexpected signing certificate in $(basename "$apk"): ${cert:-missing}" >&2
    if [[ -n "$cert_line" ]]; then
      printf 'Certificate output: %s\n' "$cert_line" >&2
    else
      printf '%s\n' "$signer_output" | grep -i 'certificate' | head -n 8 >&2 || true
    fi
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
    verified_version_name=$(printf '%s\n' "$first_line" | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")
    verified_version_code=$(printf '%s\n' "$first_line" | sed -n "s/.*versionCode='\([^']*\)'.*/\1/p")
    if [[ -n "$expected_version_name" && "$verified_version_name" != "$expected_version_name" ]]; then
      echo "Unexpected ChatGPT versionName in base APK: got=${verified_version_name:-missing} expected=$expected_version_name" >&2
      exit 1
    fi
    if [[ -n "$expected_version_code" && "$verified_version_code" != "$expected_version_code" ]]; then
      echo "Unexpected ChatGPT versionCode in base APK: got=${verified_version_code:-missing} expected=$expected_version_code" >&2
      exit 1
    fi
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
if [[ "$require_x86_64" == true ]] && (( x86_64_evidence == 0 )); then
  echo 'Verified package has no x86_64 split/native-library evidence.' >&2
  exit 1
fi

printf 'Verified ChatGPT XAPK package=%s version=%s code=%s apk_count=%d cert_sha256=%s x86_64_evidence=%d require_x86_64=%s\n' \
  "$expected_package" "${verified_version_name:-unknown}" "${verified_version_code:-unknown}" "${#apks[@]}" \
  "${expected_cert,,}" "$x86_64_evidence" "$require_x86_64"
