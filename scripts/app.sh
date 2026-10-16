#!/bin/sh
# Build RetroTube.app into build/.
# Usage: scripts/app.sh
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP="$ROOT/build/RetroTube.app"
rm -rf "$APP"
mkdir -p "$APP"

# shellcheck disable=SC2046
"$ROOT/build.sh" "$APP/RetroTube" -I"$ROOT/src/core" -I"$ROOT/src/ui" \
    $(ls "$ROOT"/src/core/*.m "$ROOT"/src/ui/*.m) \
    -framework Foundation -framework UIKit -framework CoreGraphics -framework QuartzCore \
    -framework MediaPlayer -framework AVFoundation -framework CoreMedia

cp "$ROOT/resources/Info.plist" "$APP/Info.plist"
cp "$ROOT"/resources/*.png "$APP/"
printf 'APPL????' > "$APP/PkgInfo"
echo "$APP"
