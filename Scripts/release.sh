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
SKIP_TESTS="${SKIP_TESTS:-0}"
SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"
ALLOW_DIRTY="${ALLOW_DIRTY:-0}"
KEEP_WORK="${KEEP_WORK:-0}"

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

SUFFIX=""
if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
    SUFFIX="-unnotarized"
fi
OUTPUT_DIR="$ROOT/dist/$VERSION$SUFFIX"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/jostle-release.XXXXXX")"
ARCHIVE_PATH="$WORK_DIR/Jostle.xcarchive"
APP_PATH="$WORK_DIR/Jostle.app"
PRE_NOTARY_ZIP="$WORK_DIR/Jostle-notary.zip"
DMG_ROOT="$WORK_DIR/dmg-root"
FINAL_ZIP="$OUTPUT_DIR/Jostle-$VERSION$SUFFIX.zip"
FINAL_DMG="$OUTPUT_DIR/Jostle-$VERSION$SUFFIX.dmg"
DSYM_ZIP="$OUTPUT_DIR/Jostle-$VERSION-dSYMs.zip"
CHECKSUMS="$OUTPUT_DIR/Jostle-$VERSION$SUFFIX-SHA256SUMS.txt"

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

ARCHIVED_APP="$ARCHIVE_PATH/Products/Applications/Jostle.app"
if [[ ! -d "$ARCHIVED_APP" ]]; then
    echo "error: archive did not contain Jostle.app" >&2
    exit 1
fi
ditto "$ARCHIVED_APP" "$APP_PATH"

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

if [[ "$SKIP_NOTARIZATION" != "1" ]]; then
    echo "==> Submitting application for notarization"
    ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$PRE_NOTARY_ZIP"
    xcrun notarytool submit "$PRE_NOTARY_ZIP" \
        --keychain-profile "$NOTARY_PROFILE" \
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
if diskutil image create from --help >/dev/null 2>&1; then
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
        --keychain-profile "$NOTARY_PROFILE" \
        --wait
    xcrun stapler staple "$FINAL_DMG"
    xcrun stapler validate "$FINAL_DMG"

    echo "==> Running Gatekeeper assessments"
    spctl --assess --type execute --verbose=4 "$APP_PATH"
    spctl --assess --type open --context context:primary-signature --verbose=4 "$FINAL_DMG"
fi

echo "==> Writing checksums"
(
    cd "$OUTPUT_DIR"
    FILES=("$(basename "$FINAL_ZIP")" "$(basename "$FINAL_DMG")")
    if [[ -f "$DSYM_ZIP" ]]; then
        FILES+=("$(basename "$DSYM_ZIP")")
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
