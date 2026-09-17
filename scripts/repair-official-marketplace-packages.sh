#!/usr/bin/env bash
set -euo pipefail

package_version="${MARKETPLACE_PACKAGE_VERSION:-1.0.1}"
source_ref="${MARKETPLACE_SOURCE_REF:-${GITHUB_SHA:-}}"
repository="${GITHUB_REPOSITORY:-bhrumom/fabushi}"
output_dir="${MARKETPLACE_OUTPUT_DIR:-${RUNNER_TEMP:-/tmp}/official-marketplace-packages}"
release_tag="${MARKETPLACE_RELEASE_TAG:-marketplace-v${package_version}-${source_ref:0:12}}"

if [[ ! "$source_ref" =~ ^[0-9a-fA-F]{40}$ ]]; then
  echo "MARKETPLACE_SOURCE_REF must be a 40-character commit: $source_ref" >&2
  exit 1
fi

rm -rf -- "$output_dir"
mkdir -p "$output_dir"
staging_dir="$(mktemp -d)"
trap 'rm -rf -- "$staging_dir"' EXIT

source_url="https://github.com/$repository"

recover_legacy_package() {
  local plugin_id="$1"
  local legacy_version="$2"
  local archive="marketplace/packages/$plugin_id/$legacy_version/app.tar.gz"
  local destination="$staging_dir/$plugin_id"
  local recovered_tar="$staging_dir/$plugin_id.tar"
  local gzip_status

  test -f "$archive"
  mkdir -p "$destination"

  # The historical faliu/hermes archives contain a readable tar stream but
  # fail their gzip trailer check. Recover that stream only in CI, then write
  # a fresh deterministic gzip member below.
  set +e
  gzip -dc "$archive" > "$recovered_tar"
  gzip_status=$?
  set -e
  tar -tf "$recovered_tar" >/dev/null
  tar -xf "$recovered_tar" -C "$destination"
  if [ "$gzip_status" -ne 0 ]; then
    echo "Recovered legacy archive with non-zero gzip trailer status: $archive"
  fi
  test -f "$destination/fabushi-miniapp.json"
  test -f "$destination/index.html"
  jq --arg version "$package_version" --arg source "$source_url" \
    '.version = $version | .source = $source' \
    "$destination/fabushi-miniapp.json" > "$destination/manifest.tmp"
  mv "$destination/manifest.tmp" "$destination/fabushi-miniapp.json"
}

create_chatgpt_package() {
  local plugin_id="chatgpt-auto-confirm"
  local destination="$staging_dir/$plugin_id"
  mkdir -p "$destination"
  cp .agents/plugins/plugins/chatgpt-auto-confirm/index.html "$destination/index.html"
  jq -n \
    --arg id "$plugin_id" \
    --arg version "$package_version" \
    --arg source "$source_url" \
    '{
      protocol: "fabushi.miniapp.package.v1",
      id: $id,
      version: $version,
      title: "ChatGPT 自动确认",
      entry: "index.html",
      runtime: "local-web",
      modes: ["GUI", "MCP", "桌面"],
      commands: ["status", "start", "stop"],
      mcp: "https://api.ombhrum.com/api/mcp/apps/chatgpt-auto-confirm",
      cli: null,
      source: $source
    }' > "$destination/fabushi-miniapp.json"
}

write_package() {
  local plugin_id="$1"
  local destination="$staging_dir/$plugin_id"
  local asset_name="$plugin_id-$package_version.tar.gz"
  local output_path="$output_dir/$asset_name"
  local artifact_sha
  local artifact_size

  test -f "$destination/fabushi-miniapp.json"
  test -f "$destination/index.html"
  tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner \
    -C "$destination" -cf - . | gzip -n > "$output_path"
  gzip -t "$output_path"
  tar -tzf "$output_path" | grep -Fx './fabushi-miniapp.json' >/dev/null
  tar -tzf "$output_path" | grep -Fx './index.html' >/dev/null

  artifact_sha="$(sha256sum "$output_path" | awk '{print $1}')"
  artifact_size="$(stat -c '%s' "$output_path")"
  jq -n \
    --arg plugin_id "$plugin_id" \
    --arg version "$package_version" \
    --arg source_ref "$source_ref" \
    --arg release_tag "$release_tag" \
    --arg asset_name "$asset_name" \
    --arg artifact_url "https://github.com/$repository/releases/download/$release_tag/$asset_name" \
    --arg sha256 "$artifact_sha" \
    --argjson size "$artifact_size" \
    '{
      pluginId: $plugin_id,
      version: $version,
      sourceRef: $source_ref,
      releaseTag: $release_tag,
      assetName: $asset_name,
      artifactUrl: $artifact_url,
      artifactSha256: $sha256,
      artifactSize: $size,
      format: "tar-gz",
      entry: "index.html",
      runtime: "local-web"
    }' > "$output_dir/$plugin_id.json"
}

recover_legacy_package faliu-flashcards 1.0.0
recover_legacy_package hermes-installer 1.0.0
create_chatgpt_package
write_package faliu-flashcards
write_package hermes-installer
write_package chatgpt-auto-confirm

artifact_array="$(jq -s '.' \
  "$output_dir/faliu-flashcards.json" \
  "$output_dir/hermes-installer.json" \
  "$output_dir/chatgpt-auto-confirm.json")"
jq -n \
  --arg repository "$repository" \
  --arg source_ref "$source_ref" \
  --arg version "$package_version" \
  --arg release_tag "$release_tag" \
  --argjson artifacts "$artifact_array" \
  '{schemaVersion: 1, protocol: "fabushi.marketplace.install.v1", repository: $repository, sourceRef: $source_ref, version: $version, releaseTag: $release_tag, artifacts: $artifacts}' \
  > "$output_dir/official-marketplace-release-manifest.json"

echo "Repaired official Marketplace packages:"
jq -r '.artifacts[] | [.pluginId, .version, .artifactSha256, (.artifactSize|tostring), .assetName] | @tsv' \
  "$output_dir/official-marketplace-release-manifest.json"
