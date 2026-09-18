#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="Jostle.xcodeproj"
SCHEME="Jostle"
CONFIGURATION="Release"
TEAM_ID="${DEVELOPMENT_TEAM:-7KGB78B22T}"
IDENTITY="${DEVELOPER_IDENTITY:-Developer ID Application: Paul Friedman (7KGB78B22T)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-JostleNotary}"
NOTARY_KEYCHAIN="${NOTARY_KEYCHAIN:-}"
SKIP_TESTS="${SKIP_TESTS:-0}"
SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"
ALLOW_DIRTY="${ALLOW_DIRTY:-0}"
KEEP_WORK="${KEEP_WORK:-0}"
SPARKLE_KEY_ACCOUNT="${SPARKLE_KEY_ACCOUNT:-fm.pau.jostle}"
SPARKLE_ED_PRIVATE_KEY="${SPARKLE_ED_PRIVATE_KEY:-}"

if [[ "$ALLOW_DIRTY" != "1" ]] && [[ -n "$(git status --porcelain)" ]]; then
    echo "error: the working tree must be clean (or set ALLOW_DIRTY=1 for a local validation build)" >&2
    exit 1
fi

BUILD_SETTINGS="$(xcodebuild \
    -project "$PROJECT" \
    -target "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -showBuildSettings 2>/dev/null)"
VERSION="$(awk -F ' = ' '/ MARKETING_VERSION = / { print $2; exit }' <<< "$BUILD_SETTINGS")"
BUILD_NUMBER="$(awk -F ' = ' '/ CURRENT_PROJECT_VERSION = / { print $2; exit }' <<< "$BUILD_SETTINGS")"

if [[ ! "$VERSION" =~ ^[0-9]{4}\.[0-9]{1,2}\.[0-9]+$ ]]; then
    echo "error: MARKETING_VERSION must use YYYY.MM.PATCH; found '$VERSION'" >&2
    exit 1
fi
if [[ ! "$BUILD_NUMBER" =~ ^[0-9]{10}$ ]]; then
    echo "error: CURRENT_PROJECT_VERSION must use YYYYMMDDNN; found '$BUILD_NUMBER'" >&2
    exit 1
fi
VERSION_PREFIX="${VERSION%%.*}$(cut -d. -f2 <<< "$VERSION" | awk '{ printf "%02d", $1 }')"
if [[ "$BUILD_NUMBER" != "$VERSION_PREFIX"* ]]; then
    echo "error: build '$BUILD_NUMBER' does not match release year/month '$VERSION_PREFIX'" >&2
    exit 1
fi

if ! security find-identity -v -p codesigning | grep -Fq "\"$IDENTITY\""; then
    echo "error: signing identity is not available: $IDENTITY" >&2
    exit 1
fi

NOTARY_ARGUMENTS=(--keychain-profile "$NOTARY_PROFILE")
if [[ -n "$NOTARY_KEYCHAIN" ]]; then
    NOTARY_ARGUMENTS+=(--keychain "$NOTARY_KEYCHAIN")
fi

SUFFIX=""
if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
    SUFFIX="-unnotarized"
fi
OUTPUT_DIR="$ROOT/dist/$VERSION$SUFFIX"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/jostle-release.XXXXXX")"
ARCHIVE_PATH="$WORK_DIR/Jostle.xcarchive"
EXPORT_PATH="$WORK_DIR/export"
EXPORT_OPTIONS="$WORK_DIR/ExportOptions.plist"
APP_PATH="$WORK_DIR/Jostle.app"
PRE_NOTARY_ZIP="$WORK_DIR/Jostle-notary.zip"
DMG_ROOT="$WORK_DIR/dmg-root"
FINAL_ZIP="$OUTPUT_DIR/Jostle-$VERSION$SUFFIX.zip"
FINAL_DMG="$OUTPUT_DIR/Jostle-$VERSION$SUFFIX.dmg"
DSYM_ZIP="$OUTPUT_DIR/Jostle-$VERSION-dSYMs.zip"
CHECKSUMS="$OUTPUT_DIR/Jostle-$VERSION$SUFFIX-SHA256SUMS.txt"
APPCAST="$OUTPUT_DIR/appcast.xml"
APPCAST_WORK_DIR="$WORK_DIR/appcast"

cleanup() {
    if [[ "$KEEP_WORK" == "1" ]]; then
        echo "Preserved working directory: $WORK_DIR"
    else
        rm -rf "$WORK_DIR"
    fi
}
trap cleanup EXIT

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "==> Jostle $VERSION ($BUILD_NUMBER)"

if [[ "$SKIP_TESTS" != "1" ]]; then
    echo "==> Running Xcode tests"
    xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination 'platform=macOS' \
        -derivedDataPath "$WORK_DIR/TestDerivedData" \
        CODE_SIGNING_ALLOWED=NO \
        clean test

    echo "==> Running optimized core tests"
    swift test --package-path JostleCore -c release
fi

echo "==> Creating Developer ID archive"
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath "$WORK_DIR/ArchiveDerivedData" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$IDENTITY" \
    OTHER_CODE_SIGN_FLAGS="--timestamp"

cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>$IDENTITY</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
</dict>
</plist>
EOF

echo "==> Exporting Developer ID application"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS"

EXPORTED_APP="$EXPORT_PATH/Jostle.app"
if [[ ! -d "$EXPORTED_APP" ]]; then
    echo "error: Developer ID export did not contain Jostle.app" >&2
    exit 1
fi
ditto "$EXPORTED_APP" "$APP_PATH"

ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
ACTUAL_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
if [[ "$ACTUAL_VERSION" != "$VERSION" || "$ACTUAL_BUILD" != "$BUILD_NUMBER" ]]; then
    echo "error: archived version is $ACTUAL_VERSION ($ACTUAL_BUILD), expected $VERSION ($BUILD_NUMBER)" >&2
    exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
grep -Fq "Authority=$IDENTITY" <<< "$SIGNATURE_DETAILS"
grep -Fq "TeamIdentifier=$TEAM_ID" <<< "$SIGNATURE_DETAILS"
grep -Eq 'flags=.*runtime' <<< "$SIGNATURE_DETAILS"
grep -Fq 'Timestamp=' <<< "$SIGNATURE_DETAILS"

SPARKLE_ROOT="$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/Current"
SPARKLE_COMPONENTS=(
    "$SPARKLE_ROOT"
    "$SPARKLE_ROOT/Updater.app"
    "$SPARKLE_ROOT/Autoupdate"
    "$SPARKLE_ROOT/XPCServices/Downloader.xpc"
    "$SPARKLE_ROOT/XPCServices/Installer.xpc"
)
for component in "${SPARKLE_COMPONENTS[@]}"; do
    if [[ ! -e "$component" ]]; then
        echo "error: exported application is missing Sparkle component: $component" >&2
        exit 1
    fi
    COMPONENT_SIGNATURE="$(codesign -dv --verbose=4 "$component" 2>&1)"
    grep -Fq "Authority=$IDENTITY" <<< "$COMPONENT_SIGNATURE"
    grep -Fq "TeamIdentifier=$TEAM_ID" <<< "$COMPONENT_SIGNATURE"
    grep -Eq 'flags=.*runtime' <<< "$COMPONENT_SIGNATURE"
    grep -Fq 'Timestamp=' <<< "$COMPONENT_SIGNATURE"
done

ARCHITECTURES="$(lipo -archs "$APP_PATH/Contents/MacOS/Jostle")"
for architecture in arm64 x86_64; do
    if [[ " $ARCHITECTURES " != *" $architecture "* ]]; then
        echo "error: release binary is missing $architecture; found '$ARCHITECTURES'" >&2
        exit 1
    fi
done
LOAD_COMMANDS="$(otool -l "$APP_PATH/Contents/MacOS/Jostle")"
if [[ "$LOAD_COMMANDS" != *"path @executable_path/../Frameworks"* ]]; then
    echo "error: release binary is missing the embedded-framework runpath" >&2
    exit 1
fi

if [[ "$SKIP_NOTARIZATION" != "1" ]]; then
    echo "==> Submitting application for notarization"
    ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$PRE_NOTARY_ZIP"
    xcrun notarytool submit "$PRE_NOTARY_ZIP" \
        "${NOTARY_ARGUMENTS[@]}" \
        --wait
    xcrun stapler staple "$APP_PATH"
    xcrun stapler validate "$APP_PATH"
fi

echo "==> Creating ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$FINAL_ZIP"

if [[ -d "$ARCHIVE_PATH/dSYMs" ]]; then
    echo "==> Archiving debug symbols"
    ditto -c -k --sequesterRsrc --keepParent "$ARCHIVE_PATH/dSYMs" "$DSYM_ZIP"
fi

echo "==> Creating DMG"
mkdir -p "$DMG_ROOT"
ditto "$APP_PATH" "$DMG_ROOT/Jostle.app"
ln -s /Applications "$DMG_ROOT/Applications"
DISKUTIL_IMAGE_HELP="$(diskutil image create from --help 2>&1 || true)"
if grep -q -- '--volumeName' <<< "$DISKUTIL_IMAGE_HELP"; then
    diskutil image create from \
        --volumeName "Jostle $VERSION" \
        --format UDZO \
        "$DMG_ROOT" \
        "$FINAL_DMG"
else
    hdiutil create \
        -volname "Jostle $VERSION" \
        -srcfolder "$DMG_ROOT" \
        -format UDZO \
        -ov \
        "$FINAL_DMG"
fi
codesign --force --timestamp --sign "$IDENTITY" "$FINAL_DMG"
codesign --verify --verbose=2 "$FINAL_DMG"

if [[ "$SKIP_NOTARIZATION" != "1" ]]; then
    echo "==> Submitting DMG for notarization"
    xcrun notarytool submit "$FINAL_DMG" \
        "${NOTARY_ARGUMENTS[@]}" \
        --wait
    xcrun stapler staple "$FINAL_DMG"
    xcrun stapler validate "$FINAL_DMG"

    echo "==> Running Gatekeeper assessments"
    spctl --assess --type execute --verbose=4 "$APP_PATH"
    spctl --assess --type open --context context:primary-signature --verbose=4 "$FINAL_DMG"

    echo "==> Signing Sparkle update and generating appcast"
    GENERATE_APPCAST="$(find \
        "$WORK_DIR/ArchiveDerivedData/SourcePackages/artifacts" \
        -type f \
        -path '*/Sparkle/bin/generate_appcast' \
        -print \
        -quit)"
    if [[ -z "$GENERATE_APPCAST" || ! -x "$GENERATE_APPCAST" ]]; then
        echo "error: Sparkle generate_appcast tool was not found" >&2
        exit 1
    fi

    mkdir -p "$APPCAST_WORK_DIR"
    cp "$FINAL_ZIP" "$APPCAST_WORK_DIR/$(basename "$FINAL_ZIP")"
    awk -v version="$VERSION" '
        $0 ~ "^## " version " " { capture = 1; next }
        capture && /^## / { exit }
        capture { print }
    ' CHANGELOG.md > "$APPCAST_WORK_DIR/Jostle-$VERSION.md"
    if [[ ! -s "$APPCAST_WORK_DIR/Jostle-$VERSION.md" ]]; then
        echo "error: no release notes found for $VERSION" >&2
        exit 1
    fi

    APPCAST_ARGUMENTS=(
        --download-url-prefix "https://github.com/paulfri/jostle/releases/download/v$VERSION/"
        --embed-release-notes
        --link "https://github.com/paulfri/jostle/releases/tag/v$VERSION"
        --maximum-deltas 0
        -o "$APPCAST_WORK_DIR/appcast.xml"
    )
    if [[ -n "$SPARKLE_ED_PRIVATE_KEY" ]]; then
        printf '%s' "$SPARKLE_ED_PRIVATE_KEY" | \
            "$GENERATE_APPCAST" --ed-key-file - "${APPCAST_ARGUMENTS[@]}" "$APPCAST_WORK_DIR"
    else
        "$GENERATE_APPCAST" \
            --account "$SPARKLE_KEY_ACCOUNT" \
            "${APPCAST_ARGUMENTS[@]}" \
            "$APPCAST_WORK_DIR"
    fi
    cp "$APPCAST_WORK_DIR/appcast.xml" "$APPCAST"

    xmllint --noout "$APPCAST"
    grep -Fq "Jostle-$VERSION.zip" "$APPCAST"
    grep -Fq "<sparkle:version>$BUILD_NUMBER</sparkle:version>" "$APPCAST"
    grep -Fq 'sparkle:edSignature=' "$APPCAST"
fi

echo "==> Writing checksums"
(
    cd "$OUTPUT_DIR"
    FILES=("$(basename "$FINAL_ZIP")" "$(basename "$FINAL_DMG")")
    if [[ -f "$DSYM_ZIP" ]]; then
        FILES+=("$(basename "$DSYM_ZIP")")
    fi
    if [[ -f "$APPCAST" ]]; then
        FILES+=("$(basename "$APPCAST")")
    fi
    shasum -a 256 "${FILES[@]}" > "$(basename "$CHECKSUMS")"
)

cat <<EOF

Release artifacts are ready:
  $OUTPUT_DIR

Version: $VERSION
Build:   $BUILD_NUMBER
EOF
if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
    echo "WARNING: These validation artifacts are not notarized and must not be published."
fi
