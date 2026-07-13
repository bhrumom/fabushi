#!/usr/bin/env bash
set -euo pipefail

tag="rust-v0.144.1"
commit="db75c19352d29ef29c17dbcf73a7244f1b1a8d10"
target="${1:-../mahayana-cli-upstream}"

git clone --depth 1 --branch "$tag" https://github.com/openai/codex.git "$target"
git -C "$target" remote rename origin openai
test "$(git -C "$target" rev-parse HEAD)" = "$commit"
git -C "$target" switch -c mahayana
echo "Pinned Mahayana source ready at $target. Apply patches/ before building."
