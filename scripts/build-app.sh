#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-icon.sh
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$PWD/build/Mus.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
# Replace the executable inode rather than truncating a possibly running binary.
cp "$BIN_DIR/Mus" "$APP_DIR/Contents/MacOS/Mus.new"
mv -f "$APP_DIR/Contents/MacOS/Mus.new" "$APP_DIR/Contents/MacOS/Mus"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
ditto "$BIN_DIR/Mus_Mus.bundle" "$APP_DIR/Contents/Resources/Mus_Mus.bundle"
if [[ -f Resources/AppIcon.icns ]]; then
    cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
fi
# Set SIGN_IDENTITY to a Developer ID for distributed builds. Local builds are ad-hoc signed.
codesign --force --sign "${SIGN_IDENTITY:--}" --identifier local.mus.app "$APP_DIR"
codesign --verify --strict "$APP_DIR"
printf '\nBuilt: %s\n' "$APP_DIR"
