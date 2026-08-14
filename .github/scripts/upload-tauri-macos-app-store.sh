#!/usr/bin/env bash
set -euo pipefail

status_dir="${MACOS_APP_STORE_STATUS_DIR:-$PWD/macos-app-store-assets}"
mkdir -p "$status_dir"
status_file="$status_dir/TAURI_MACOS_APP_STORE_UPLOAD_STATUS.txt"

write_status() {
  local status="$1"
  local reason="$2"
  {
    echo "status=$status"
    echo "reason=$reason"
    echo "source_sha=${SOURCE_SHA:-${GITHUB_SHA:-}}"
    echo "app_version=${APP_VERSION:-}"
    echo "build_number=${RELEASE_BUILD_NUMBER:-}"
    echo "uploaded_at=${3:-}"
  } > "$status_file"
}

trap 'code=$?; if [ "$code" -ne 0 ]; then write_status failed "tauri_macos_app_store_upload_failed_exit_${code}"; fi' EXIT

require_config() {
  local missing=()
  for name in "$@"; do
    if [ -z "${!name:-}" ]; then missing+=("$name"); fi
  done
  if [ "${#missing[@]}" -ne 0 ]; then
    printf 'Missing required configuration: %s\n' "${missing[*]}" >&2
    write_status failed "missing_app_store_configuration"
    exit 1
  fi
}

require_config \
  APP_STORE_CONNECT_API_KEY_ID \
  APP_STORE_CONNECT_API_ISSUER_ID \
  APP_STORE_CONNECT_API_KEY_BASE64 \
  MACOS_APP_STORE_TEAM_ID \
  MACOS_APP_STORE_BUNDLE_ID \
  MACOS_APP_STORE_CERTIFICATE_P12_BASE64 \
  MACOS_APP_STORE_CERTIFICATE_PASSWORD \
  MACOS_APP_STORE_INSTALLER_CERTIFICATE_P12_BASE64 \
  MACOS_APP_STORE_INSTALLER_CERTIFICATE_PASSWORD \
  MACOS_APP_STORE_PROVISIONING_PROFILE_BASE64 \
  APP_VERSION \
  RELEASE_BUILD_NUMBER

app_path="${TAURI_APP_PATH:-}"
if [ -z "$app_path" ]; then
  app_path="$(find third_party/mahayana/mahayana-rs/target/release/bundle/macos -maxdepth 1 -type d -name '*.app' -print | sort | head -n 1)"
fi
if [ -z "$app_path" ] || [ ! -d "$app_path" ]; then
  echo "Unable to find bundled Tauri .app" >&2
  exit 1
fi

marketplace_path="$app_path/Contents/Resources/fabushi-official/marketplace.json"
if [ ! -f "$marketplace_path" ]; then
  echo "Bundled marketplace is missing: $marketplace_path" >&2
  find "$app_path/Contents/Resources" -maxdepth 3 -type f -print >&2 || true
  exit 1
fi

info_plist="$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${MACOS_APP_STORE_BUNDLE_ID}" "$info_plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${APP_VERSION}" "$info_plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${RELEASE_BUILD_NUMBER}" "$info_plist"

cert_path="$RUNNER_TEMP/macos_app_store_distribution.p12"
installer_cert_path="$RUNNER_TEMP/macos_installer_distribution.p12"
profile_path="$RUNNER_TEMP/fabushi-macos.provisionprofile"
profile_plist="$RUNNER_TEMP/fabushi-macos-profile.plist"
keychain_path="$RUNNER_TEMP/macos-app-store-signing.keychain-db"
keychain_password="${GITHUB_RUN_ID:-fabushi}-${GITHUB_RUN_ATTEMPT:-1}"

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

app_identity="$(security find-identity -v -p codesigning | awk -F '"' '/Mac App Distribution|Apple Distribution/ { print $2; exit }')"
installer_identity="$(security find-identity -v | awk -F '"' '/Mac Installer Distribution|3rd Party Mac Developer Installer/ { print $2; exit }')"
if [ -z "$app_identity" ] || [ -z "$installer_identity" ]; then
  echo "Unable to resolve App Store signing identities" >&2
  security find-identity -v >&2 || true
  exit 1
fi

security cms -D -i "$profile_path" > "$profile_plist"
profile_team_id="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$profile_plist")"
profile_app_identifier="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.application-identifier' "$profile_plist" 2>/dev/null || true)"
if [ "$profile_team_id" != "$MACOS_APP_STORE_TEAM_ID" ]; then
  echo "Provisioning profile team mismatch: $profile_team_id" >&2
  exit 1
fi
expected_app_identifier="${MACOS_APP_STORE_TEAM_ID}.${MACOS_APP_STORE_BUNDLE_ID}"
if [ -n "$profile_app_identifier" ] && [ "$profile_app_identifier" != "$expected_app_identifier" ]; then
  echo "Provisioning profile app identifier mismatch: $profile_app_identifier" >&2
  exit 1
fi
cp "$profile_path" "$app_path/Contents/embedded.provisionprofile"

entitlements="apps/fabushi-tauri/src-tauri/AppStore.entitlements"
find "$app_path/Contents" -type f -perm -111 -print0 | while IFS= read -r -d '' executable; do
  if file -b "$executable" | grep -q 'Mach-O'; then
    codesign --force --sign "$app_identity" "$executable"
  fi
done
codesign --force --deep --sign "$app_identity" --entitlements "$entitlements" "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"

pkg_path="$status_dir/Fabushi-${APP_VERSION}-${RELEASE_BUILD_NUMBER}-macos-app-store.pkg"
productbuild --component "$app_path" /Applications --sign "$installer_identity" "$pkg_path"
pkgutil --check-signature "$pkg_path"

api_key_dir="$HOME/.appstoreconnect/private_keys"
api_key_path="$api_key_dir/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
mkdir -p "$api_key_dir"
printf '%s' "$APP_STORE_CONNECT_API_KEY_BASE64" | base64 --decode > "$api_key_path"
chmod 600 "$api_key_path"

xcrun altool --validate-app \
  --type macos \
  --file "$pkg_path" \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_API_ISSUER_ID"

set +e
upload_output="$(xcrun altool --upload-app \
  --type macos \
  --file "$pkg_path" \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_API_ISSUER_ID" 2>&1)"
upload_code=$?
set -e
printf '%s\n' "$upload_output"
if [ "$upload_code" -ne 0 ]; then
  if printf '%s' "$upload_output" | grep -Eq 'ATTRIBUTE.INVALID.DUPLICATE|bundle version must be higher|already been used'; then
    write_status uploaded already_uploaded_to_app_store_connect "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    exit 0
  fi
  exit "$upload_code"
fi

write_status uploaded accepted_by_app_store_connect "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
