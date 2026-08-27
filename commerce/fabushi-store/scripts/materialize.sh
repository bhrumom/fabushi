#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT_DIR}/../.." && pwd)"
DESTINATION="${1:-${REPO_ROOT}/.work/fabushi-store}"
UPSTREAM_REPO="https://github.com/medusajs/dtc-starter.git"
UPSTREAM_COMMIT="cb603dfda0a82e8bb5e81622f295e0ff90ac6913"

rm -rf "${DESTINATION}"
git clone --filter=blob:none --no-checkout "${UPSTREAM_REPO}" "${DESTINATION}"
git -C "${DESTINATION}" fetch --depth 1 origin "${UPSTREAM_COMMIT}"
git -C "${DESTINATION}" checkout --detach "${UPSTREAM_COMMIT}"

actual="$(git -C "${DESTINATION}" rev-parse HEAD)"
if [[ "${actual}" != "${UPSTREAM_COMMIT}" ]]; then
  echo "upstream verification failed: expected ${UPSTREAM_COMMIT}, got ${actual}" >&2
  exit 1
fi

cp -a "${ROOT_DIR}/overlay/." "${DESTINATION}/"
printf '%s\n' "${UPSTREAM_COMMIT}" > "${DESTINATION}/.fabushi-upstream-commit"
echo "Materialized Fabushi Store at ${DESTINATION} from ${UPSTREAM_REPO}@${UPSTREAM_COMMIT}"
