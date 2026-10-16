#!/bin/sh
# Build and run the tests of the core code.
# Usage: scripts/test.sh [--phone] [NAME]
# With no option, the tests operate on this Mac.
# With --phone, the tests operate on the iPhone at "ssh iphone4s".
# NAME runs only the tests with NAME in their name.
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/build/tests"
mkdir -p "$OUT"
SOURCES=$(ls "$ROOT"/src/core/*.m "$ROOT"/tests/*.m 2>/dev/null || true)

if [ "$1" = "--phone" ]; then
    shift
    "$ROOT/build.sh" "$OUT/rttests-armv7" -I"$ROOT/src/core" -I"$ROOT/tests" $SOURCES -framework Foundation
    scp -q "$OUT/rttests-armv7" iphone4s:/tmp/rttests
    ssh iphone4s "ldid -S /tmp/rttests && RT_LIVE=${RT_LIVE:-} /tmp/rttests $*"
else
    clang -fobjc-arc -Wall -Werror -mmacosx-version-min=10.9 -I"$ROOT/src/core" -I"$ROOT/tests" $SOURCES \
        -framework Foundation -o "$OUT/rttests"
    "$OUT/rttests" "$@"
fi
