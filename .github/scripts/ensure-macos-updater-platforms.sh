#!/usr/bin/env bash
# Merge the macOS universal updater archive into latest.json.
#
# tauri-action matrix jobs race when uploading latest.json, so darwin platforms
# are often missing even when URW_universal.app.tar.gz was published. Installed
# Mac apps look up darwin-aarch64 / darwin-x86_64, not only darwin-universal.
set -euo pipefail

LATEST_JSON="${1:-dist/latest.json}"

if [[ -z "${RELEASE_TAG:-}" || -z "${GH_REPO:-}" ]]; then
  echo "RELEASE_TAG and GH_REPO must be set." >&2
  exit 1
fi

if [[ ! -s "${LATEST_JSON}" ]]; then
  echo "latest.json not found at ${LATEST_JSON}" >&2
  exit 1
fi

mac_asset="$(
  gh release view "${RELEASE_TAG}" --json assets --jq '
    .assets[].name
    | select(test("(?i)\\.app\\.tar\\.gz$"))
  ' | head -n 1
)"

if [[ -z "${mac_asset}" ]]; then
  echo "No macOS .app.tar.gz updater archive on ${RELEASE_TAG}." >&2
  exit 1
fi

sig_asset="${mac_asset}.sig"
sig_tmp="$(mktemp -d)"
cleanup() { rm -rf "${sig_tmp}"; }
trap cleanup EXIT

gh release download "${RELEASE_TAG}" --pattern "${sig_asset}" --dir "${sig_tmp}" --clobber
if [[ ! -s "${sig_tmp}/${sig_asset}" ]]; then
  echo "Missing signature asset ${sig_asset} on ${RELEASE_TAG}." >&2
  exit 1
fi

sig="$(tr -d '\n\r' < "${sig_tmp}/${sig_asset}")"
url="https://github.com/${GH_REPO}/releases/download/${RELEASE_TAG}/${mac_asset}"

tmp="$(mktemp)"
jq --arg url "${url}" --arg sig "${sig}" '
  .platforms["darwin-aarch64"] = {url: $url, signature: $sig}
  | .platforms["darwin-x86_64"] = {url: $url, signature: $sig}
  | .platforms["darwin-universal"] = {url: $url, signature: $sig}
' "${LATEST_JSON}" > "${tmp}"
mv "${tmp}" "${LATEST_JSON}"

for key in darwin-aarch64 darwin-x86_64 darwin-universal; do
  jq -e --arg k "${key}" '.platforms[$k].url and (.platforms[$k].signature | length > 0)' "${LATEST_JSON}" >/dev/null
done

echo "Ensured macOS updater platforms from ${mac_asset} on ${RELEASE_TAG}."
jq -r '.platforms | keys[]' "${LATEST_JSON}" | sed 's/^/ - /'
