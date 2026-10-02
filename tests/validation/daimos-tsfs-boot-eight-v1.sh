#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
host_cc=${HOST_CC:-cc}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-tsfs-boot-eight-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

"$host_cc" -std=c99 -pedantic -O2 -Wall -Wextra -Werror -DKINIT_FULL=1 \
        -I"$DAIMOS_REPO/system/kernel/boot" \
        -I"$DAIMOS_REPO/system/kernel/core" \
        -I"$DAIMOS_REPO/system/kernel/fs" \
        -I"$DAIMOS_REPO/system/kernel/modules" \
        -I"$DAIMOS_REPO/system/kernel/proc" \
        -I"$DAIMOS_REPO/system/kernel/storage" \
        -I"${PDP10_PREFIX:?PDP10_PREFIX must be set}/include" \
        "$self/daimos-tsfs-boot-eight-v1.c" \
        "$DAIMOS_REPO/system/kernel/boot/tsfs_boot.c" -o "$work/test"
"$work/test"
