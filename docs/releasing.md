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

`notarytool` prompts securely for the app-specific password and validates it before storing it. CI should use protected App Store Connect API-key secrets instead of an app-specific password.

## Build a release

Start from a clean checkout on the commit intended for release, update both version build settings, and run:

```sh
Scripts/release.sh
```

The script:

1. Validates CalVer, build numbering, Git cleanliness, and the signing identity.
2. Runs the Xcode suite and optimized `JostleCore` suite.
3. Creates a hardened-runtime Developer ID archive.
4. Verifies the application signature, authority, team, version, and build.
5. Submits the application to Apple and staples its notarization ticket.
6. Creates the release ZIP and dSYM archive.
7. Creates, signs, notarizes, and staples a drag-install DMG.
8. Runs Gatekeeper assessments and writes SHA-256 checksums.

Final artifacts are written under `dist/<version>/`.

For local pipeline development only, notarization can be skipped:

```sh
ALLOW_DIRTY=1 SKIP_TESTS=1 SKIP_NOTARIZATION=1 Scripts/release.sh
```

Those files include `-unnotarized` in their names and must never be published.

## Publish

After manually checking the packaged application:

```sh
git tag -a v2026.9.0 -m "Jostle 2026.9.0"
git push origin main
git push origin v2026.9.0

gh release create v2026.9.0 \
  dist/2026.9.0/Jostle-2026.9.0.dmg \
  dist/2026.9.0/Jostle-2026.9.0.zip \
  dist/2026.9.0/Jostle-2026.9.0-dSYMs.zip \
  dist/2026.9.0/Jostle-2026.9.0-SHA256SUMS.txt
```

Do not tag or publish until notarization and both Gatekeeper assessments succeed.

## Sparkle

Sparkle will use the notarized ZIP after the first direct release pipeline is proven. Its EdDSA private key must be protected separately from Apple signing and notarization credentials.
