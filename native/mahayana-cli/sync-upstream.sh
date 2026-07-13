#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=codex-upstream.env
source "${script_dir}/codex-upstream.env"
target="${1:-${script_dir}/../mahayana-cli-upstream}"

git clone --depth 1 --branch "$CODEX_UPSTREAM_TAG" "$CODEX_UPSTREAM_REPOSITORY" "$target"
git -C "$target" remote rename origin openai
test "$(git -C "$target" rev-parse HEAD)" = "$CODEX_UPSTREAM_COMMIT"
git -C "$target" switch -c mahayana
echo "Pinned Codex source ready at $target for the Mahayana release bundle."
