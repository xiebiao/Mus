#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ICONSET="$PWD/build/Mus.iconset"
mkdir -p "$ICONSET"
# Use the user-selected transparent mouse silhouette for every build.
cp Resources/IconVariants/Mus-Mouse-Template.png Resources/AppIcon.png
sips -z 128 128 Resources/AppIcon.png --out Sources/Mus/Resources/MusLogo.png >/dev/null
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
