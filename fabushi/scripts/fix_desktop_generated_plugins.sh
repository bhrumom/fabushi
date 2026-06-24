#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

patch_macos() {
  local registrant="$ROOT_DIR/macos/Flutter/GeneratedPluginRegistrant.swift"
  local plugin_deps="$ROOT_DIR/.flutter-plugins-dependencies"

  if [[ -f "$registrant" ]]; then
    local tmp_file
    tmp_file="$(mktemp)"
    awk '
      /^import flutter_sound$/ { next }
      /FlutterSoundPlugin\.register\(with:/ { next }
      { print }
    ' "$registrant" > "$tmp_file"
    mv "$tmp_file" "$registrant"
  fi

  if [[ -f "$plugin_deps" ]]; then
    node -e '
      const fs = require("fs");
      const file = process.argv[1];
      const data = JSON.parse(fs.readFileSync(file, "utf8"));
      if (data.plugins && Array.isArray(data.plugins.macos)) {
        data.plugins.macos = data.plugins.macos.filter(
          (plugin) => plugin && plugin.name !== "flutter_sound",
        );
      }
      fs.writeFileSync(file, JSON.stringify(data));
    ' "$plugin_deps"
  fi
}

patch_linux() {
  local registrant="$ROOT_DIR/linux/flutter/generated_plugin_registrant.cc"
  local cmake_file="$ROOT_DIR/linux/flutter/generated_plugins.cmake"

  if [[ -f "$registrant" ]]; then
    perl -0pi -e 's/#include <(?:flutter_sound\/flutter_sound_plugin|taudio\/taudio_plugin)\.h>\n//g' "$registrant"
    perl -0pi -e 's/\n  g_autoptr\(FlPluginRegistrar\) flutter_sound_registrar =\n      fl_plugin_registry_get_registrar_for_plugin\(registry, "FlutterSoundPlugin"\);\n  (?:flutter_sound_plugin_register_with_registrar|taudio_plugin_register_with_registrar)\(flutter_sound_registrar\);\n/\n/g' "$registrant"
  fi

  remove_cmake_flutter_sound "$cmake_file" linux
}

patch_windows() {
  local registrant="$ROOT_DIR/windows/flutter/generated_plugin_registrant.cc"
  local cmake_file="$ROOT_DIR/windows/flutter/generated_plugins.cmake"

  if [[ -f "$registrant" ]]; then
    perl -0pi -e 's/#include <(?:flutter_sound\/flutter_sound_plugin_c_api|taudio\/taudio_plugin_c_api)\.h>\n//g' "$registrant"
    perl -0pi -e 's/\n  (?:FlutterSoundPluginCApiRegisterWithRegistrar|TaudioPluginCApiRegisterWithRegistrar)\(\n      registry->GetRegistrarForPlugin\("(?:FlutterSoundPluginCApi|TaudioPluginCApi)"\)\);\n/\n/g' "$registrant"
  fi

  remove_cmake_flutter_sound "$cmake_file" windows
  patch_cmake_rive_common_windows "$cmake_file"
}

patch_cmake_rive_common_windows() {
  local cmake_file="$1"

  if [[ ! -f "$cmake_file" ]]; then
    return 0
  fi

  if grep -q "Wno-nontrivial-memcall" "$cmake_file"; then
    return 0
  fi

  cat >> "$cmake_file" <<'EOF'

if(TARGET rive_common_plugin)
  target_compile_options(rive_common_plugin PRIVATE -Wno-nontrivial-memcall)
endif()
EOF
}

remove_cmake_flutter_sound() {
  local cmake_file="$1"
  local platform="$2"

  if [[ ! -f "$cmake_file" ]]; then
    return 0
  fi

  local tmp_file
  tmp_file="$(mktemp)"
  awk -v platform="$platform" '
    /^[[:space:]]+flutter_sound[[:space:]]*$/ {
      next
    }

    $0 == "add_subdirectory(flutter/ephemeral/.plugin_symlinks/flutter_sound/" platform " plugins/flutter_sound)" {
      skip_taudio_block = 4
      next
    }

    skip_taudio_block > 0 {
      skip_taudio_block--
      next
    }

    {
      print
    }
  ' "$cmake_file" > "$tmp_file"
  mv "$tmp_file" "$cmake_file"
}

patch_macos
patch_linux
patch_windows

echo "Patched generated desktop plugin files for stale flutter_sound targets."
