#!/bin/sh
# Build RetroTube.app, copy it to the phone at "ssh iphone4s", and open it.
# Usage: scripts/install.sh
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
"$ROOT/scripts/app.sh" >/dev/null

ssh iphone4s 'killall RetroTube >/dev/null 2>&1; rm -rf /Applications/RetroTube.app'
# The sftp server of the phone cannot make a new directory, so copy with tar.
# COPYFILE_DISABLE stops macOS tar from adding "._" files.
COPYFILE_DISABLE=1 tar --no-xattrs -C "$ROOT/build" -cf - RetroTube.app | ssh iphone4s 'tar -C /Applications -xf -'
# uicache must run as the mobile user, so that SpringBoard sees the new icon.
ssh iphone4s 'ldid -S /Applications/RetroTube.app/RetroTube &&
    chown -R root:admin /Applications/RetroTube.app &&
    chmod 755 /Applications/RetroTube.app/RetroTube &&
    su mobile -c uicache &&
    open io.github.stivengjekaj.retrotube'
