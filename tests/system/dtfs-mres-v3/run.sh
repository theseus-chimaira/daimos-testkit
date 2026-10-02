#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:?TMPDIR must be set}"
BUILD_ROOT=${BUILD_ROOT:-"$PWD/build"}
DTFS_MRES_MAX_WORDS=${DTFS_MRES_MAX_WORDS:-3000}
DAIMOS_BUILD_ROOT="$BUILD_ROOT/tests/system/dtfs-mres-v3"
OBJDUMP="$PDP10_PREFIX/bin/pdp10-objdump"
if [ ! -x "$OBJDUMP" ]; then
    echo "missing pdp10-objdump: $OBJDUMP" >&2
    exit 1
fi

measure()
{
    name=$1
    limit=$2
    root="$DAIMOS_BUILD_ROOT/$name"
    obj="$root/system/boot/pdp6/dtfs-mres.dobj"

    mkdir -p "$root"
    make -C "$DAIMOS_REPO/system/boot/pdp6" \
        BUILD_ROOT="$root" PDP10_PREFIX="$PDP10_PREFIX" \
        image
    if [ ! -f "$obj" ]; then
        echo "missing DTFS MRES object: $obj" >&2
        exit 1
    fi
    words=$(
        "$OBJDUMP" -h "$obj" |
        awk '/^sections:/ { for (i=1;i<=NF;++i) if ($i ~ /^data=/) { split($i,a,"="); print a[2]; exit } }'
    )
    case "$words" in
    ''|*[!0-9]*) echo "could not read DTFS resident word count" >&2; exit 1;;
    esac
    if [ "$words" -gt "$limit" ]; then
        echo "DTFS MRES $name regression: $words words > $limit" >&2
        exit 1
    fi
    printf 'DTFS MRES %s: %s words (limit %s): PASS\n' \
        "$name" "$words" "$limit"
}

# Native, ITS, and TENEX DECtape personalities are mandatory in the supported
# build, so there is one resident DTFS package profile rather than separate
# native/foreign size configurations.
measure required "$DTFS_MRES_MAX_WORDS"
