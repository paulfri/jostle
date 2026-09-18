# Releasing Jostle

Jostle is distributed outside the Mac App Store as a Developer ID-signed and Apple-notarized application. Release versions use CalVer.

## Version numbers

- `MARKETING_VERSION`: `YYYY.MM.PATCH`, for example `2026.9.0`.
- `CURRENT_PROJECT_VERSION`: `YYYYMMDDNN`, for example `2026091701`.
- Git tag: `v` followed by the marketing version, for example `v2026.9.0`.

Increment `PATCH` for additional releases in the same month. Increment the final two build-number digits for multiple builds on the same day. Both values are defined on the Jostle target in `Jostle.xcodeproj/project.pbxproj` and are expanded into the application’s Info.plist.

## One-time signing setup

Install a **Developer ID Application** certificate for Team `7KGB78B22T` through Xcode’s Accounts settings. A Developer ID Installer certificate is not required because Jostle ships as ZIP and DMG archives.

Keep a secure backup of the certificate and its private key. Never commit certificate exports, private keys, Apple credentials, or app-specific passwords.

## One-time notarization setup

Create an app-specific password for the Apple ID associated with the developer team. Then store it in the local Keychain under the profile expected by the release script:

```sh
xcrun notarytool store-credentials JostleNotary \
  --apple-id "YOUR_APPLE_ID" \
  --team-id 7KGB78B22T
```

`notarytool` prompts securely for the app-specific password and validates it before storing it.

## One-time GitHub Actions setup

Export only the **Developer ID Application** certificate and its private key from Keychain Access as a password-protected PKCS#12 (`.p12`) file. Configure these encrypted repository secrets:

```sh
base64 < DeveloperIDApplication.p12 | gh secret set DEVELOPER_ID_P12_BASE64 -R paulfri/jostle
gh secret set DEVELOPER_ID_P12_PASSWORD -R paulfri/jostle
gh secret set APPLE_ID -R paulfri/jostle
gh secret set APPLE_APP_SPECIFIC_PASSWORD -R paulfri/jostle
```

The final three commands prompt for their values. Delete the exported `.p12` after confirming the secrets. Never place it inside the repository. The GitHub Actions runner imports it into an ephemeral keychain that is deleted after the job.

## Build a release locally

Start from a clean checkout on the commit intended for release, update both version build settings, and run:

```sh
Scripts/release.sh
```

The script:

1. Validates CalVer, build numbering, Git cleanliness, and the signing identity.
2. Runs the Xcode suite and optimized `JostleCore` suite.
3. Creates an archive and exports it for Developer ID distribution so Sparkle’s nested helpers are re-signed correctly.
4. Verifies the application and Sparkle helper signatures, authorities, secure timestamps, team, version, and build.
5. Submits the application to Apple and staples its notarization ticket.
6. Creates the release ZIP and dSYM archive.
7. Creates, signs, notarizes, and staples a drag-install DMG.
8. Runs Gatekeeper assessments.
9. Signs the notarized ZIP with Sparkle’s EdDSA key and generates `appcast.xml`.
10. Writes SHA-256 checksums for the distributable artifacts and appcast.

Final artifacts are written under `dist/<version>/`.

For local pipeline development only, notarization can be skipped:

```sh
ALLOW_DIRTY=1 SKIP_TESTS=1 SKIP_NOTARIZATION=1 Scripts/release.sh
```

Those files include `-unnotarized` in their names and must never be published.

## Publish through GitHub Actions

After manually checking a local packaged application, replace `Unreleased` in the changelog heading with the release date, commit, and push `main`. Then create and push the matching annotated tag:

```sh
git push origin main
git tag -a v2026.9.0 -m "Jostle 2026.9.0"
git push origin v2026.9.0
```

`.github/workflows/release.yml` validates the tag against `MARKETING_VERSION`, rejects an unreleased changelog, imports the encrypted certificate, and runs the complete release script on a clean GitHub runner. Only after tests, both notarizations, stapling, and Gatekeeper assessments succeed does it publish the GitHub Release.

The release contains the DMG, EdDSA-signed Sparkle ZIP, `appcast.xml`, dSYMs, and SHA-256 checksums. The same files are retained as a private workflow artifact for 90 days. Re-running the workflow safely replaces assets on an existing release.

## Sparkle signing and appcast

Jostle embeds only the Sparkle EdDSA public key. The private key is stored locally in the login Keychain under account `fm.pau.jostle` and in GitHub’s encrypted `SPARKLE_ED_PRIVATE_KEY` repository secret. It is independent of the Developer ID certificate and notarization credentials.

Sparkle’s tools are supplied by the pinned Swift package. To create the key once, resolve packages, locate the tools under Xcode’s `SourcePackages/artifacts/sparkle/Sparkle/bin/`, and run:

```sh
generate_keys --account fm.pau.jostle
```

Copy the printed public key into `SUPublicEDKey` in `Jostle/Jostle-Info.plist`. Export the private key only long enough to configure CI:

```sh
generate_keys --account fm.pau.jostle -x /tmp/jostle-sparkle-private-key
gh secret set SPARKLE_ED_PRIVATE_KEY -R paulfri/jostle \
  < /tmp/jostle-sparkle-private-key
rm -f /tmp/jostle-sparkle-private-key
```

Keep an additional encrypted offline backup. Never commit or retain an unencrypted exported key file.

For a notarized release, `Scripts/release.sh` finds `generate_appcast` in Xcode’s resolved Sparkle artifact, signs the release ZIP, embeds that version’s changelog notes, and produces `appcast.xml`. GitHub Actions uploads the appcast as a release asset. The application uses this permanent feed URL:

```text
https://github.com/paulfri/jostle/releases/latest/download/appcast.xml
```

Each appcast points to the notarized ZIP attached to the same tagged GitHub release. Automatic checks default off and can be enabled in Jostle’s Updates settings. The `2026.9.1` release bootstraps Sparkle; in-app update testing begins with the following release because earlier builds did not contain Sparkle.
