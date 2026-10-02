#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:?TMPDIR must be set}"
BUILD_ROOT=${BUILD_ROOT:-"$PWD/build"}
D6FS_MRES_MAX_WORDS=${D6FS_MRES_MAX_WORDS:-2367}
DAIMOS_BUILD_ROOT="$BUILD_ROOT/tests/system/d6fs-mres-v1/daimos-build-v1"
OBJDUMP="$PDP10_PREFIX/bin/pdp10-objdump"
BOOT_BUILD="$DAIMOS_BUILD_ROOT/system/boot/pdp6"
REPORT="$DAIMOS_REPO/system/boot/pdp6/image/report-permanent.sh"
if [ ! -x "$OBJDUMP" ]; then
    echo "missing pdp10-objdump: $OBJDUMP" >&2
    exit 1
fi
mkdir -p "$DAIMOS_BUILD_ROOT"
make -C "$DAIMOS_REPO/system/boot/pdp6" \
    BUILD_ROOT="$DAIMOS_BUILD_ROOT" PDP10_PREFIX="$PDP10_PREFIX" image
if [ ! -x "$REPORT" ]; then
    echo "missing permanent-size reporter: $REPORT" >&2
    exit 1
fi
words=$(
    "$REPORT" --kcore-map "$BOOT_BUILD/kcore.map" \
        --build "$BOOT_BUILD" --objdump "$OBJDUMP" --omit-blockset |
    awk '$1 == "MRES" && $2 == "d6fs" { print $4; exit }'
)
case "$words" in ''|*[!0-9]*) echo "could not read D6FS resident word count" >&2; exit 1;; esac
if [ "$words" -gt "$D6FS_MRES_MAX_WORDS" ]; then
    echo "D6FS MRES regression: $words words > $D6FS_MRES_MAX_WORDS" >&2
    exit 1
fi
printf 'D6FS MRES: %s words (limit %s): PASS\n' "$words" "$D6FS_MRES_MAX_WORDS"
