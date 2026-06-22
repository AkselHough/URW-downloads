# Certum SimplySign + GitHub Actions

URW macOS builds run on GitHub-hosted `macos-14` runners in [build-release.yml](../.github/workflows/build-release.yml). Production signing expects a `.p12` in the `APPLE_CERTIFICATE` secret.

## Your certificate

| Field | Value |
| --- | --- |
| Provider | Certum SimplySign (cloud) |
| CN | Aksel Sebastian Halrynjo-Hough |
| Team ID | `35CK8NVYK6` |
| Signing identity | `Developer ID Application: Aksel Sebastian Halrynjo-Hough (35CK8NVYK6)` |
| SHA-1 | `9E2865A053FFABE139F940B1ACCE39FC356A8AE3` |
| SimplySign account | akselhhough@gmail.com |

## Path A — Export a .p12 (try this first)

1. Open **SimplySign Desktop** and connect to the cloud (OTP from the mobile app).
2. **Keychain Access** → **login** → **My Certificates**.
3. Expand **Developer ID Application: Aksel Sebastian Halrynjo-Hough (35CK8NVYK6)**.
4. Select **both** the certificate and the private key underneath.
5. Right-click → **Export 2 items…** → save as `URW-DeveloperID.p12` with a strong password.

If export succeeds:

```bash
base64 -i URW-DeveloperID.p12 | pbcopy   # → APPLE_CERTIFICATE
# APPLE_CERTIFICATE_PASSWORD = export password
# KEYCHAIN_PASSWORD = random string (see prepare-signing-secrets.sh)
```

The existing workflow imports this via `apple-actions/import-codesign-certs@v2` — no workflow changes needed.

If **Export** is greyed out or the imported `.p12` has no private key, the cloud HSM key is not extractable. Use Path B.

## Path B — Self-hosted Mac runner

Keep SimplySign Desktop on a Mac you control. The runner authenticates to Certum before each build; codesign uses the identity already in the login keychain.

1. Register a self-hosted runner on **URW-downloads** (Settings → Actions → Runners).
2. Install SimplySign Desktop and import the certificate on that Mac.
3. Store `CERTUM_OTP_URI` (the `otpauth://` secret from SimplySign setup) and `CERTUM_USERNAME` (`akselhhough@gmail.com`) as GitHub secrets.
4. Change the macOS job in `build-release.yml` to `runs-on: [self-hosted, macOS]` and replace the `import-codesign-certs` step with a script that launches SimplySign and submits the TOTP (same pattern as [debrief-dev/debrief](https://github.com/debrief-dev/debrief/commit/ada9aad)).

## Path C — Second Apple Developer ID cert (local key)

If you have access to [developer.apple.com](https://developer.apple.com/account/resources/certificates/list) for team `35CK8NVYK6`, you can issue a **second** Developer ID Application certificate with a CSR generated on your Mac. The private key stays local and exports cleanly to `.p12` for CI. Revoke unused duplicates to stay within Apple’s limit.

## Notarization (all paths)

Notarization uses an **App Store Connect API key**, not the Certum cert:

1. [App Store Connect → Integrations → API](https://appstoreconnect.apple.com/access/integrations/api)
2. Create a key (Developer access), download the `.p8` once.
3. Secrets: `APPLE_API_KEY_BASE64`, `APPLE_API_KEY_ID`, `APPLE_API_ISSUER`, plus `APPLE_TEAM_ID`.

## Quick setup script

```bash
chmod +x .github/scripts/prepare-signing-secrets.sh
.github/scripts/prepare-signing-secrets.sh
```
