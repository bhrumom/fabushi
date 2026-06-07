#!/usr/bin/env bash
set -eo pipefail

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

homebrew_deps=()

has_dep() {
  local needle="$1"
  local dep
  for dep in "${homebrew_deps[@]}"; do
    if [ "$dep" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

add_dep() {
  local dep="$1"
  [ -n "$dep" ] || return 0
  if ! has_dep "$dep"; then
    homebrew_deps+=("$dep")
  fi
}

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

rewrite_dep_target() {
  local dep="$1"
  case "$(basename "$dep")" in
    libz.1.dylib)
      printf '%s\n' /usr/lib/libz.1.dylib
      ;;
    *)
      printf '@rpath/%s\n' "$(basename "$dep")"
      ;;
  esac
}

should_bundle_dep() {
  local dep="$1"
  case "$(rewrite_dep_target "$dep")" in
    @rpath/*) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_dep_path() {
  local dep="$1"
  local dep_name
  local candidate

  if ! should_bundle_dep "$dep"; then
    return 1
  fi

  if [ -f "$dep" ]; then
    printf '%s\n' "$dep"
    return 0
  fi

  dep_name="$(basename "$dep")"
  for candidate in \
    "/opt/homebrew/lib/$dep_name" \
    "/usr/local/lib/$dep_name"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

while IFS= read -r -d '' file; do
  while IFS= read -r dep; do
    add_dep "$dep"
  done < <(collect_homebrew_deps "$file")
done < <(find "$app_path/Contents" -type f \( -perm -111 -o -name '*.dylib' -o -path '*.framework/Versions/*/*' \) -print0)

if [ "${#homebrew_deps[@]}" -eq 0 ]; then
  echo "No Homebrew dynamic library references found in $app_path."
  exit 0
fi

index=0
while [ "$index" -lt "${#homebrew_deps[@]}" ]; do
  dep="${homebrew_deps[$index]}"
  if should_bundle_dep "$dep"; then
    dep_path="$(resolve_dep_path "$dep" || true)"
    if [ -z "$dep_path" ]; then
      echo "Unable to locate Homebrew dependency referenced by bundle: $dep" >&2
      exit 1
    fi

    while IFS= read -r nested_dep; do
      add_dep "$nested_dep"
    done < <(collect_homebrew_deps "$dep_path")
  fi

  index=$((index + 1))
done

for dep in "${homebrew_deps[@]}"; do
  if ! should_bundle_dep "$dep"; then
    echo "Rewriting $dep to $(rewrite_dep_target "$dep") without bundling."
    continue
  fi

  dep_path="$(resolve_dep_path "$dep" || true)"
  if [ -z "$dep_path" ]; then
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
    install_name_tool -change "$dep" "$(rewrite_dep_target "$dep")" "$file"
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
