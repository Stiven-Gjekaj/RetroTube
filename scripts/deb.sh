#!/bin/sh
# Build the Cydia package of RetroTube into build/.
# Usage: scripts/deb.sh
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
"$ROOT/scripts/app.sh" >/dev/null
VERSION=$(plutil -extract CFBundleShortVersionString raw "$ROOT/resources/Info.plist")
NAME="io.github.stivengjekaj.retrotube_${VERSION}_iphoneos-arm.deb"

# iOS 6 reads only the first code directory, so SHA-1 must be first.
codesign -s - --digest-algorithm=sha1,sha256 -f "$ROOT/build/RetroTube.app/RetroTube" 2>/dev/null

STAGE="$ROOT/build/deb"
rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" "$STAGE/Applications"
cp -R "$ROOT/build/RetroTube.app" "$STAGE/Applications/"
sed "s/@VERSION@/$VERSION/" "$ROOT/packaging/control" > "$STAGE/DEBIAN/control"
cp "$ROOT/packaging/postinst" "$ROOT/packaging/postrm" "$STAGE/DEBIAN/"
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm" "$STAGE/Applications/RetroTube.app/RetroTube"
xattr -cr "$STAGE"

# The dpkg of Cydia on iOS 6 reads gzip, not xz or zstd.
dpkg-deb -Zgzip --root-owner-group -b "$STAGE" "$ROOT/build/$NAME" >/dev/null
echo "$ROOT/build/$NAME"
