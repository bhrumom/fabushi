#!/usr/bin/env bash
set -euo pipefail

status_dir="${MACOS_APP_STORE_STATUS_DIR:-$PWD/../macos-app-store-assets}"
mkdir -p "$status_dir"
status_file="$status_dir/MACOS_APP_STORE_UPLOAD_STATUS.txt"

write_status() {
  local status="$1"
  local reason="$2"
  {
    echo "status=$status"
    echo "reason=$reason"
    echo "source_sha=${SOURCE_SHA:-}"
    echo "app_version=${APP_VERSION:-}"
    echo "build_number=${RELEASE_BUILD_NUMBER:-}"
    echo "uploaded_at=${3:-}"
  } > "$status_file"
}

handle_altool_result() {
  local action="$1"
  local exit_code="$2"
  local log_file="$3"

  if [ "$exit_code" -eq 0 ]; then
    return 0
  fi

  if grep -Eq "ATTRIBUTE.INVALID.DUPLICATE|value that has already been used|bundle version must be higher" "$log_file" &&
     grep -Eq "previousBundleVersion = ${build_number};|previously uploaded version: .${build_number}." "$log_file"; then
    echo "App Store Connect already has build number ${build_number}; treating ${action} as an idempotent success."
    write_status "uploaded" "already_uploaded_to_app_store_connect" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    exit 0
  fi

  return "$exit_code"
}

run_altool() {
  local action="$1"
  shift
  local log_file="$status_dir/MACOS_APP_STORE_${action}_ALTOOL.log"

  set +e
  "$@" 2>&1 | tee "$log_file"
  local exit_code="${PIPESTATUS[0]}"
  set -e

  handle_altool_result "$action" "$exit_code" "$log_file"
}

trap 'exit_code=$?; if [ "$exit_code" -ne 0 ]; then write_status "failed" "macos_app_store_upload_failed_exit_${exit_code}"; fi' EXIT

require_config() {
  local missing=()
  for name in "$@"; do
    if [ -z "${!name:-}" ]; then
      missing+=("$name")
    fi
  done

  if [ "${#missing[@]}" -eq 0 ]; then
    return 0
  fi

  {
    echo "macOS App Store Connect upload is not configured."
    echo ""
    echo "Missing configuration:"
    printf -- "- %s\n" "${missing[@]}"
  } > "$status_dir/MACOS_APP_STORE_NOT_CONFIGURED.txt"

  write_status "skipped" "macos_app_store_connect_not_configured"
  if [ "${MACOS_APP_STORE_UPLOAD_REQUIRED:-false}" = "true" ]; then
    cat "$status_dir/MACOS_APP_STORE_NOT_CONFIGURED.txt" >&2
    exit 1
  fi

  cat "$status_dir/MACOS_APP_STORE_NOT_CONFIGURED.txt"
  exit 0
}

case "${MACOS_APP_STORE_UPLOAD_ENABLED:-true}" in
  true|TRUE|True|1|yes|YES) ;;
  *)
    write_status "skipped" "macos_app_store_upload_disabled"
    echo "macOS App Store Connect upload is disabled."
    exit 0
    ;;
esac

require_config \
  APP_STORE_CONNECT_API_KEY_ID \
  APP_STORE_CONNECT_API_ISSUER_ID \
  APP_STORE_CONNECT_API_KEY_BASE64 \
  MACOS_APP_STORE_TEAM_ID \
  MACOS_APP_STORE_BUNDLE_ID

version_name="${APP_VERSION%%+*}"
build_number="${RELEASE_BUILD_NUMBER:-${APP_VERSION##*+}}"
if [ -z "$version_name" ] || [ "$version_name" = "$APP_VERSION" ] || [ -z "$build_number" ]; then
  echo "APP_VERSION must use Flutter's x.y.z+build format; got '$APP_VERSION'." >&2
  exit 1
fi

api_key_dir="$RUNNER_TEMP/appstoreconnect/private_keys"
altool_api_key_dir="$HOME/.appstoreconnect/private_keys"
api_key_path="$api_key_dir/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
altool_api_key_path="$altool_api_key_dir/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
mkdir -p "$api_key_dir" "$altool_api_key_dir"
printf '%s' "$APP_STORE_CONNECT_API_KEY_BASE64" | base64 --decode > "$api_key_path"
cp "$api_key_path" "$altool_api_key_path"
chmod 600 "$api_key_path" "$altool_api_key_path"

auth_args=(
  -authenticationKeyPath "$api_key_path"
  -authenticationKeyID "$APP_STORE_CONNECT_API_KEY_ID"
  -authenticationKeyIssuerID "$APP_STORE_CONNECT_API_ISSUER_ID"
)

manual_signing=false
if [ -n "${MACOS_APP_STORE_CERTIFICATE_P12_BASE64:-}" ] ||
   [ -n "${MACOS_APP_STORE_CERTIFICATE_PASSWORD:-}" ] ||
   [ -n "${MACOS_APP_STORE_INSTALLER_CERTIFICATE_P12_BASE64:-}" ] ||
   [ -n "${MACOS_APP_STORE_INSTALLER_CERTIFICATE_PASSWORD:-}" ] ||
   [ -n "${MACOS_APP_STORE_PROVISIONING_PROFILE_BASE64:-}" ]; then
  for name in \
    MACOS_APP_STORE_CERTIFICATE_P12_BASE64 \
    MACOS_APP_STORE_CERTIFICATE_PASSWORD \
    MACOS_APP_STORE_INSTALLER_CERTIFICATE_P12_BASE64 \
    MACOS_APP_STORE_INSTALLER_CERTIFICATE_PASSWORD \
    MACOS_APP_STORE_PROVISIONING_PROFILE_BASE64; do
    if [ -z "${!name:-}" ]; then
      echo "$name is required when any manual macOS App Store signing secret is configured." >&2
      exit 1
    fi
  done
  manual_signing=true
fi

profile_name=""
if [ "$manual_signing" = "true" ]; then
  cert_path="$RUNNER_TEMP/macos_app_store_distribution.p12"
  installer_cert_path="$RUNNER_TEMP/macos_installer_distribution.p12"
  profile_path="$RUNNER_TEMP/fabushi-macos.provisionprofile"
  profile_plist="$RUNNER_TEMP/fabushi-macos-profile.plist"
  keychain_password="${KEYCHAIN_PASSWORD:-${GITHUB_RUN_ID:-macos-app-store}-${GITHUB_RUN_ATTEMPT:-1}}"
  keychain_path="$RUNNER_TEMP/macos-app-store-signing.keychain-db"

  printf '%s' "$MACOS_APP_STORE_CERTIFICATE_P12_BASE64" | base64 --decode > "$cert_path"
  printf '%s' "$MACOS_APP_STORE_INSTALLER_CERTIFICATE_P12_BASE64" | base64 --decode > "$installer_cert_path"
  printf '%s' "$MACOS_APP_STORE_PROVISIONING_PROFILE_BASE64" | base64 --decode > "$profile_path"

  security create-keychain -p "$keychain_password" "$keychain_path"
  security set-keychain-settings -lut 21600 "$keychain_path"
  security unlock-keychain -p "$keychain_password" "$keychain_path"
  security import "$cert_path" -P "$MACOS_APP_STORE_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$keychain_path"
  security import "$installer_cert_path" -P "$MACOS_APP_STORE_INSTALLER_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$keychain_path"
  security list-keychains -d user -s "$keychain_path" login.keychain-db
  security default-keychain -s "$keychain_path"
  security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain_path"

  mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
  security cms -D -i "$profile_path" > "$profile_plist"
  profile_name="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$profile_plist")"
  profile_uuid="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$profile_plist")"
  profile_team_id="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$profile_plist")"
  profile_app_identifier="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.application-identifier' "$profile_plist" 2>/dev/null || true)"
  cp "$profile_path" "$HOME/Library/MobileDevice/Provisioning Profiles/$profile_uuid.provisionprofile"

  if [ "$profile_team_id" != "$MACOS_APP_STORE_TEAM_ID" ]; then
    echo "Provisioning profile team '$profile_team_id' does not match MACOS_APP_STORE_TEAM_ID '$MACOS_APP_STORE_TEAM_ID'." >&2
    exit 1
  fi
  expected_profile_app_identifier="${MACOS_APP_STORE_TEAM_ID}.${MACOS_APP_STORE_BUNDLE_ID}"
  if [ -n "$profile_app_identifier" ] && [ "$profile_app_identifier" != "$expected_profile_app_identifier" ]; then
    echo "Provisioning profile app identifier '$profile_app_identifier' does not match '$expected_profile_app_identifier'." >&2
    exit 1
  fi

  ruby - \
    macos/Runner.xcodeproj/project.pbxproj \
    "$MACOS_APP_STORE_TEAM_ID" \
    "$MACOS_APP_STORE_BUNDLE_ID" \
    "$version_name" \
    "$build_number" \
    "${MACOS_APP_STORE_SIGNING_CERTIFICATE:-Mac App Distribution}" \
    "$profile_name" <<'RUBY'
project_path, team_id, bundle_id, version_name, build_number, signing_identity, profile_name = ARGV
text = File.read(project_path)

def render_build_value(value)
  value = value.to_s
  return value if value.match?(/\A[A-Za-z0-9_.+-]+\z/)

  '"' + value.gsub('\\', '\\\\\\').gsub('"', '\\"') + '"'
end

target_match = text.match(/^\s*([A-F0-9]+) \/\* Runner \*\/ = \{\n\s*isa = PBXNativeTarget;\n.*?^\s*\};/m)
raise "Unable to find Runner target in #{project_path}" unless target_match

target_id = target_match[1]
target_block = target_match[0]
config_list_id = target_block[/buildConfigurationList = ([A-F0-9]+)/, 1]
raise "Unable to find Runner build configuration list" unless config_list_id

config_list_match = text.match(/^\s*#{Regexp.escape(config_list_id)} \/\* Build configuration list for PBXNativeTarget "Runner" \*\/ = \{\n.*?^\s*\};/m)
raise "Unable to resolve Runner build configuration list #{config_list_id}" unless config_list_match

runner_configs = config_list_match[0].scan(/([A-F0-9]+) \/\* (Debug|Release|Profile) \*\//)
raise "Unable to find Runner Release build configuration" unless runner_configs.any? { |_, name| name == "Release" }

settings = {
  "PRODUCT_BUNDLE_IDENTIFIER" => bundle_id,
  "MARKETING_VERSION" => version_name,
  "CURRENT_PROJECT_VERSION" => build_number,
  "DEVELOPMENT_TEAM" => team_id,
  "CODE_SIGN_STYLE" => "Manual",
  "CODE_SIGN_IDENTITY" => signing_identity,
  "PROVISIONING_PROFILE_SPECIFIER" => profile_name
}

runner_configs.each do |config_id, config_name|
  next unless config_name == "Release"

  config_re = /^(\s*#{Regexp.escape(config_id)} \/\* #{Regexp.escape(config_name)} \*\/ = \{\n.*?buildSettings = \{\n)(.*?)(^\s*\};\n\s*name = #{Regexp.escape(config_name)};\n\s*\};)/m
  replaced = text.sub!(config_re) do
    prefix = Regexp.last_match(1)
    body = Regexp.last_match(2)
    suffix = Regexp.last_match(3)

    settings.each do |key, value|
      rendered = "#{key} = #{render_build_value(value)};"
      if body.match?(/^(\s*)#{Regexp.escape(key)} = .*;$/)
        body = body.gsub(/^(\s*)#{Regexp.escape(key)} = .*;$/, "\\1#{rendered}")
      else
        body << "\t\t\t\t\t#{rendered}\n"
      end
    end

    prefix + body + suffix
  end

  raise "Unable to patch Runner #{config_name} build settings" unless replaced
end

target_attr_re = /^(\s*#{Regexp.escape(target_id)} = \{\n.*?ProvisioningStyle = )Automatic(;.*?^\s*\};)/m
text.sub!(target_attr_re, "\\1Manual\\2")

File.write(project_path, text)
puts "Configured Runner Release signing settings for macOS App Store archive."
RUBY
fi

archive_path="$PWD/build/macos/AppStore/global_dharma_sharing.xcarchive"
export_path="$PWD/build/macos/AppStore/export"
export_options="$RUNNER_TEMP/macos-app-store-export-options.plist"
derived_data_path="$RUNNER_TEMP/macos-app-store-derived-data"
rm -rf "$archive_path" "$export_path"
mkdir -p "$(dirname "$archive_path")" "$export_path"

flutter build macos \
  --release \
  --no-pub \
  --dart-define=DACHENG_DESKTOP_CONTROL=false \
  --config-only \
  --build-name "$version_name" \
  --build-number "$build_number"

archive_args=(
  -workspace macos/Runner.xcworkspace
  -scheme Runner
  -configuration Release
  -destination "generic/platform=macOS"
  -archivePath "$archive_path"
  -derivedDataPath "$derived_data_path"
)

if [ "$manual_signing" != "true" ]; then
  archive_args+=(
    MARKETING_VERSION="$version_name"
    CURRENT_PROJECT_VERSION="$build_number"
    PRODUCT_BUNDLE_IDENTIFIER="$MACOS_APP_STORE_BUNDLE_ID"
    DEVELOPMENT_TEAM="$MACOS_APP_STORE_TEAM_ID"
    CODE_SIGN_STYLE=Automatic
  )
fi

archive_attempts="${MACOS_APP_STORE_ARCHIVE_ATTEMPTS:-2}"
case "$archive_attempts" in
  ''|*[!0-9]*)
    echo "MACOS_APP_STORE_ARCHIVE_ATTEMPTS must be a positive integer." >&2
    exit 2
    ;;
esac
if [ "$archive_attempts" -le 0 ]; then
  echo "MACOS_APP_STORE_ARCHIVE_ATTEMPTS must be greater than zero." >&2
  exit 2
fi

archive_attempt=1
while true; do
  archive_log="$RUNNER_TEMP/macos-app-store-archive-attempt-${archive_attempt}.log"
  set +e
  xcodebuild \
    "${archive_args[@]}" \
    "${auth_args[@]}" \
    -allowProvisioningUpdates \
    clean archive 2>&1 | tee "$archive_log"
  archive_exit_code="${PIPESTATUS[0]}"
  set -e

  if [ "$archive_exit_code" -eq 0 ]; then
    break
  fi

  if [ "$archive_attempt" -lt "$archive_attempts" ] &&
     grep -Eq "Xcode build system has crashed|Build again to continue|unexpected service error" "$archive_log"; then
    echo "Xcode archive crashed during attempt ${archive_attempt}; retrying."
    rm -rf "$archive_path" "$derived_data_path"
    archive_attempt=$((archive_attempt + 1))
    continue
  fi

  exit "$archive_exit_code"
done

archived_app_path="$archive_path/Products/Applications/global_dharma_sharing.app"
fix_bundled_dylibs_script="$PWD/../.github/scripts/fix-macos-bundled-dylibs.sh"
if [ -x "$fix_bundled_dylibs_script" ]; then
  "$fix_bundled_dylibs_script" "$archived_app_path"
fi

internal_only=false
case "${MACOS_APP_STORE_INTERNAL_TESTING_ONLY:-false}" in
  true|TRUE|True|1|yes|YES) internal_only=true ;;
esac

{
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>$([ "$manual_signing" = "true" ] && echo manual || echo automatic)</string>
  <key>teamID</key>
  <string>${MACOS_APP_STORE_TEAM_ID}</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>uploadSymbols</key>
  <true/>
  <key>testFlightInternalTestingOnly</key>
EOF
  if [ "$internal_only" = "true" ]; then
    echo "  <true/>"
  else
    echo "  <false/>"
  fi
  if [ "$manual_signing" = "true" ]; then
    cat <<EOF
  <key>signingCertificate</key>
  <string>${MACOS_APP_STORE_SIGNING_CERTIFICATE:-Mac App Distribution}</string>
  <key>installerSigningCertificate</key>
  <string>${MACOS_APP_STORE_INSTALLER_SIGNING_CERTIFICATE:-Mac Installer Distribution}</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>${MACOS_APP_STORE_BUNDLE_ID}</key>
    <string>${profile_name}</string>
  </dict>
EOF
  fi
  cat <<EOF
</dict>
</plist>
EOF
} > "$export_options"

xcodebuild \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportOptionsPlist "$export_options" \
  -exportPath "$export_path" \
  "${auth_args[@]}" \
  -allowProvisioningUpdates

pkg_path="$(find "$export_path" -maxdepth 2 -name '*.pkg' -type f | sort | head -n 1)"
if [ -z "$pkg_path" ]; then
  echo "xcodebuild export completed but no macOS App Store .pkg was produced under $export_path." >&2
  find "$export_path" -maxdepth 3 -type f -print >&2 || true
  exit 1
fi

short_sha="${SOURCE_SHA:-${GITHUB_SHA:-unknown}}"
short_sha="${short_sha:0:12}"
pkg_name="global_dharma_sharing-${version_name}-${build_number}-macos-app-store-${short_sha}.pkg"
{
  echo "package_name=$pkg_name"
  echo "package_path=$pkg_path"
} > "$status_dir/MACOS_APP_STORE_PACKAGE.txt"

run_altool validate \
  xcrun altool --validate-app \
  --type macos \
  --file "$pkg_path" \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_API_ISSUER_ID"

run_altool upload \
  xcrun altool --upload-app \
  --type macos \
  --file "$pkg_path" \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_API_ISSUER_ID"

write_status "uploaded" "accepted_by_app_store_connect" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
