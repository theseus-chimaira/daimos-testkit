#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
host_cc=${HOST_CC:-cc}
tag=daimos-tsfs-scan-v2
work="$TMPDIR/$tag-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
"$host_cc" -std=c99 -pedantic -O2 -Wall -Wextra -Werror \
        -I"$DAIMOS_REPO/userland/tsfs" \
        -I"$DAIMOS_REPO/userland/libc" \
        -I"$DAIMOS_REPO/system/kernel/proc" \
        -I"$DAIMOS_REPO/system/kernel/fs" \
        -I"$DAIMOS_REPO/system/kernel/storage" \
        -I"$DAIMOS_REPO/system/kernel/core" \
        "$self/daimos-tsfs-scan-v2-test.c" \
        "$DAIMOS_REPO/userland/tsfs/tsfs_scan.c" -o "$work/test"
"$work/test"
