#!/usr/bin/env bash
set -euo pipefail

app_path="${1:-}"
if [ -z "$app_path" ]; then
  echo "Usage: $0 path/to/App.app" >&2
  exit 2
fi
if [ ! -d "$app_path" ]; then
  echo "macOS app bundle not found: $app_path" >&2
  exit 1
fi

frameworks_dir="$app_path/Contents/Frameworks"
mkdir -p "$frameworks_dir"

declare -A homebrew_deps=()
collect_homebrew_deps() {
  local binary="$1"
  otool -L "$binary" 2>/dev/null |
    awk 'NR > 1 { print $1 }' |
    while IFS= read -r dep; do
      case "$dep" in
        /opt/homebrew/*|/usr/local/opt/*|/usr/local/Cellar/*)
          printf '%s\n' "$dep"
          ;;
      esac
    done
}

while IFS= read -r -d '' file; do
  while IFS= read -r dep; do
    [ -n "$dep" ] || continue
    homebrew_deps["$dep"]=1
  done < <(collect_homebrew_deps "$file")
done < <(find "$app_path/Contents" -type f \( -perm -111 -o -name '*.dylib' -o -path '*.framework/Versions/*/*' \) -print0)

if [ "${#homebrew_deps[@]}" -eq 0 ]; then
  echo "No Homebrew dynamic library references found in $app_path."
  exit 0
fi

for dep in "${!homebrew_deps[@]}"; do
  dep_path="$dep"
  if [ ! -f "$dep_path" ]; then
    dep_name="$(basename "$dep")"
    for candidate in \
      "/opt/homebrew/lib/$dep_name" \
      "/opt/homebrew/opt/$(basename "${dep%/lib/*}")/lib/$dep_name" \
      "/usr/local/lib/$dep_name"; do
      if [ -f "$candidate" ]; then
        dep_path="$candidate"
        break
      fi
    done
  fi

  if [ ! -f "$dep_path" ]; then
    echo "Unable to locate Homebrew dependency referenced by bundle: $dep" >&2
    exit 1
  fi

  dep_name="$(basename "$dep")"
  bundled_path="$frameworks_dir/$dep_name"
  cp -f "$dep_path" "$bundled_path"
  chmod u+w "$bundled_path"
  install_name_tool -id "@rpath/$dep_name" "$bundled_path"
  echo "Bundled $dep as @rpath/$dep_name"
done

while IFS= read -r -d '' file; do
  changed=false
  while IFS= read -r dep; do
    [ -n "$dep" ] || continue
    dep_name="$(basename "$dep")"
    install_name_tool -change "$dep" "@rpath/$dep_name" "$file"
    changed=true
  done < <(collect_homebrew_deps "$file")
  if [ "$changed" = "true" ]; then
    echo "Rewrote Homebrew references in $file"
  fi
done < <(find "$app_path/Contents" -type f \( -perm -111 -o -name '*.dylib' -o -path '*.framework/Versions/*/*' \) -print0)

remaining_refs="$(
  while IFS= read -r -d '' file; do
    otool -L "$file" 2>/dev/null | awk 'NR > 1 { print $1 }'
  done < <(find "$app_path/Contents" -type f \( -perm -111 -o -name '*.dylib' -o -path '*.framework/Versions/*/*' \) -print0) |
    grep -E '^(/opt/homebrew|/usr/local/(opt|Cellar))/' || true
)"
if [ -n "$remaining_refs" ]; then
  echo "Bundle still contains external Homebrew dynamic library references:" >&2
  echo "$remaining_refs" >&2
  exit 1
fi
