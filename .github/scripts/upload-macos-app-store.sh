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

  {
    echo ""
    echo "// Injected by CI for the macOS App Store archive. Only the Runner target includes this xcconfig."
    echo "PRODUCT_BUNDLE_IDENTIFIER = $MACOS_APP_STORE_BUNDLE_ID"
    echo "MARKETING_VERSION = $version_name"
    echo "CURRENT_PROJECT_VERSION = $build_number"
    echo "DEVELOPMENT_TEAM = $MACOS_APP_STORE_TEAM_ID"
    echo "CODE_SIGN_STYLE = Manual"
    echo "CODE_SIGN_IDENTITY = ${MACOS_APP_STORE_SIGNING_CERTIFICATE:-Mac App Distribution}"
    echo "PROVISIONING_PROFILE_SPECIFIER = $profile_name"
  } >> macos/Runner/Configs/AppInfo.xcconfig
fi

archive_path="$PWD/build/macos/AppStore/global_dharma_sharing.xcarchive"
export_path="$PWD/build/macos/AppStore/export"
export_options="$RUNNER_TEMP/macos-app-store-export-options.plist"
rm -rf "$archive_path" "$export_path"
mkdir -p "$(dirname "$archive_path")" "$export_path"

flutter build macos \
  --release \
  --no-pub \
  --config-only \
  --build-name "$version_name" \
  --build-number "$build_number"

archive_args=(
  -workspace macos/Runner.xcworkspace
  -scheme Runner
  -configuration Release
  -destination "generic/platform=macOS"
  -archivePath "$archive_path"
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

xcodebuild \
  "${archive_args[@]}" \
  "${auth_args[@]}" \
  -allowProvisioningUpdates \
  clean archive

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
cp "$pkg_path" "$status_dir/$pkg_name"

xcrun altool --validate-app \
  --type macos \
  --file "$pkg_path" \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_API_ISSUER_ID"

xcrun altool --upload-app \
  --type macos \
  --file "$pkg_path" \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_API_ISSUER_ID"

write_status "uploaded" "accepted_by_app_store_connect" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
