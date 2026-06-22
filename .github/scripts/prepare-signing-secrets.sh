#!/usr/bin/env bash
# Prepare values for URW-downloads GitHub Actions secrets (run locally on your Mac).
# Does not print private key material — only copies to clipboard when you confirm.

set -euo pipefail

REPO="AkselHough/URW-downloads"
SECRETS_URL="https://github.com/${REPO}/settings/secrets/actions"

APPLE_SIGNING_IDENTITY='Developer ID Application: Aksel Sebastian Halrynjo-Hough (35CK8NVYK6)'
APPLE_TEAM_ID='35CK8NVYK6'
CERT_SHA1='9E2865A053FFABE139F940B1ACCE39FC356A8AE3'

echo "URW-downloads signing secrets setup"
echo "Add secrets at: ${SECRETS_URL}"
echo

echo "=== Fixed values (safe to copy) ==="
echo "APPLE_SIGNING_IDENTITY=${APPLE_SIGNING_IDENTITY}"
echo "APPLE_TEAM_ID=${APPLE_TEAM_ID}"
echo

echo "=== Local signing identity check ==="
if security find-identity -v -p codesigning | grep -q "${APPLE_TEAM_ID}"; then
  security find-identity -v -p codesigning | grep "${APPLE_TEAM_ID}" || true
  echo "OK: Developer ID identity is visible in this Mac keychain."
else
  echo "WARN: Identity not found. Open SimplySign Desktop and connect to the cloud first."
fi
echo

echo "=== TAURI updater signing (from ~/.tauri/urw.key) ==="
if [[ -f "${HOME}/.tauri/urw.key" && -f "${HOME}/.tauri/urw.key.pub" ]]; then
  echo "Found ~/.tauri/urw.key and urw.key.pub"
  echo "Run these when ready (raw file content, NOT base64 -i):"
  echo "  pbcopy < ~/.tauri/urw.key        # → TAURI_PRIVATE_KEY"
  echo "  pbcopy < ~/.tauri/urw.key.pub    # → TAURI_UPDATER_PUBLIC_KEY"
  echo "TAURI_PRIVATE_KEY_PASSWORD = password you set when generating the key (blank if none)"
else
  echo "Missing ~/.tauri/urw.key — generate with: npx tauri signer generate -w ~/.tauri/urw.key"
fi
echo

echo "=== KEYCHAIN_PASSWORD ==="
KEYCHAIN_PASSWORD="$(openssl rand -base64 24)"
echo "Generated throwaway CI keychain password (save as KEYCHAIN_PASSWORD secret):"
echo "${KEYCHAIN_PASSWORD}"
echo

echo "=== Apple .p12 export (Certum SimplySign) ==="
echo "SimplySign keeps the private key in the cloud. A .p12 export only works if"
echo "Keychain Access lets you export BOTH the certificate and its private key:"
echo "  1. SimplySign Desktop → Connect to the cloud (OTP from phone)"
echo "  2. Keychain Access → login → My Certificates"
echo "  3. Expand: ${APPLE_SIGNING_IDENTITY}"
echo "  4. Select certificate + private key → Export 2 items → URW-DeveloperID.p12"
echo
echo "If Export is disabled or the .p12 lacks a private key, use a self-hosted Mac"
echo "runner with SimplySign Desktop instead (see docs/certum-simplysign-ci.md)."
echo
read -r -p "Paste .p12 path to base64-encode for APPLE_CERTIFICATE (or Enter to skip): " P12_PATH
if [[ -n "${P12_PATH}" && -f "${P12_PATH}" ]]; then
  read -r -s -p "Password you set when exporting the .p12 (APPLE_CERTIFICATE_PASSWORD): " P12_PASSWORD
  echo
  base64 -i "${P12_PATH}" | pbcopy
  echo "Copied base64 .p12 to clipboard → paste into APPLE_CERTIFICATE secret."
  echo "APPLE_CERTIFICATE_PASSWORD = the export password you just entered."
else
  echo "Skipped .p12 encoding."
fi
echo

echo "=== App Store Connect API key (notarization — separate from Certum) ==="
echo "  1. https://appstoreconnect.apple.com/access/integrations/api"
echo "  2. Keys → + → name 'URW CI' → Access: Developer → Download .p8 once"
echo "  3. base64 -i AuthKey_XXXXXX.p8 | pbcopy  → APPLE_API_KEY_BASE64"
echo "  4. APPLE_API_KEY_ID = 10-char Key ID shown in the portal"
echo "  5. APPLE_API_ISSUER = Issuer ID at top of the Keys page (UUID)"
echo

echo "=== URW_SOURCE_TOKEN ==="
echo "Fine-grained PAT on AkselHough/URW with Contents: Read → URW_SOURCE_TOKEN"
echo

echo "=== Secret checklist ==="
cat <<EOF
[ ] URW_SOURCE_TOKEN
[ ] TAURI_PRIVATE_KEY
[ ] TAURI_PRIVATE_KEY_PASSWORD
[ ] TAURI_UPDATER_PUBLIC_KEY
[ ] KEYCHAIN_PASSWORD
[ ] APPLE_CERTIFICATE (+ APPLE_CERTIFICATE_PASSWORD)  OR self-hosted Mac runner
[ ] APPLE_SIGNING_IDENTITY
[ ] APPLE_TEAM_ID
[ ] APPLE_API_KEY_BASE64
[ ] APPLE_API_KEY_ID
[ ] APPLE_API_ISSUER
EOF

echo
echo "Certificate SHA-1 (for debugging): ${CERT_SHA1}"
