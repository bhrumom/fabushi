#!/usr/bin/env bash
set -euo pipefail

archive="${1:?usage: install-chatgpt-xapk.sh <xapk>}"
package_name="${CHATGPT_ANDROID_PACKAGE:-com.openai.chatgpt}"
adb_bin="${ADB_BIN:-adb}"
sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
aapt_bin=$(find "$sdk_root/build-tools" -type f -name aapt -perm -u+x -print 2>/dev/null | sort -V | tail -n 1)
if [[ -z "$aapt_bin" ]]; then
  echo 'Android aapt is required to inspect XAPK splits.' >&2
  exit 1
fi

test -s "$archive"
"$adb_bin" get-state >/dev/null

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
unzip -q "$archive" -d "$work"

base=''
while IFS= read -r apk; do
  badging=$("$aapt_bin" dump badging "$apk" 2>/dev/null || true)
  first_line=$(printf '%s\n' "$badging" | head -n 1)
  if [[ "$first_line" == *"package: name='$package_name'"* && "$first_line" != *" split='"* ]]; then
    base="$apk"
    break
  fi
done < <(find "$work" -type f -name '*.apk' -print | sort)
if [[ -z "$base" ]]; then
  echo "Unable to find the base APK for $package_name." >&2
  exit 1
fi

abilist=$("$adb_bin" shell getprop ro.product.cpu.abilist | tr -d '\r')
abi_split=''
IFS=',' read -r -a abis <<<"$abilist"
for abi in "${abis[@]}"; do
  case "$abi" in
    arm64-v8a) candidate="$work/config.arm64_v8a.apk" ;;
    armeabi-v7a) candidate="$work/config.armeabi_v7a.apk" ;;
    x86_64) candidate="$work/config.x86_64.apk" ;;
    x86) candidate="$work/config.x86.apk" ;;
    *) continue ;;
  esac
  if [[ -f "$candidate" ]]; then
    abi_split="$candidate"
    break
  fi
done
if [[ -z "$abi_split" ]]; then
  echo "No ABI split matches device ABI list: $abilist" >&2
  exit 1
fi

density=$("$adb_bin" shell wm density | tr -d '\r' | awk '/Override density:/ {v=$3} /Physical density:/ && !v {v=$3} END {print v}')
if [[ ! "$density" =~ ^[0-9]+$ ]]; then
  density=420
fi

declare -a density_names=(ldpi mdpi tvdpi hdpi xhdpi xxhdpi xxxhdpi)
declare -a density_values=(120 160 213 240 320 480 640)
density_split=''
best_delta=100000
for i in "${!density_names[@]}"; do
  candidate="$work/config.${density_names[$i]}.apk"
  [[ -f "$candidate" ]] || continue
  delta=$(( density - density_values[$i] ))
  (( delta < 0 )) && delta=$(( -delta ))
  if (( delta < best_delta )); then
    best_delta=$delta
    density_split="$candidate"
  fi
done

language_split=''
locale=$("$adb_bin" shell getprop persist.sys.locale | tr -d '\r')
lang=${locale%%[-_]*}
if [[ -z "$lang" ]]; then
  lang=en
fi
if [[ -f "$work/config.${lang}.apk" ]]; then
  language_split="$work/config.${lang}.apk"
elif [[ -f "$work/config.en.apk" ]]; then
  language_split="$work/config.en.apk"
fi

selected=("$base" "$abi_split")
[[ -n "$density_split" ]] && selected+=("$density_split")
[[ -n "$language_split" ]] && selected+=("$language_split")

printf 'Installing ChatGPT XAPK splits for abilist=%s density=%s locale=%s:\n' "$abilist" "$density" "${locale:-unknown}"
printf '  %s\n' "${selected[@]##*/}"

"$adb_bin" install-multiple -r "${selected[@]}"
if ! "$adb_bin" shell pm path "$package_name" | tr -d '\r' | grep -q '^package:'; then
  echo "$package_name was not installed after install-multiple." >&2
  exit 1
fi

printf 'Installed %s successfully.\n' "$package_name"
