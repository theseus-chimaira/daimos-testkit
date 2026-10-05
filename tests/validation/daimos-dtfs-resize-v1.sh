#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-dtfs-resize-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
{
    printf '%s\n' '.set DTFS_ENABLE_TENEX,1' '.set DTFS_ENABLE_ITS,1'
    cat "$DAIMOS_REPO/system/kernel/fs/dtfs_resize.s"
} > "$work/dtfs_resize.s"
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=c99 -Os -fno-builtin -fno-common \
    -march=pdp6 -S "$self/daimos-dtfs-resize-v1.c" -o "$work/oracle.s"
PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
    --start 1000 --step-limit 5000000 --timeout 20 \
    --workdir "$work/run" --name daimos-dtfs-resize-v1 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/oracle.s" \
    "$work/dtfs_resize.s" "$DAIMOS_REPO/system/kernel/core/ret.s" >/dev/null
printf '%s\n' 'dtfs-resize: PASS (NATIVE/TENEX grow/equal/shrink and ITS delegation)'
