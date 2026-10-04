#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-dpy-native-blocks-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
"$cc" -std=c99 -Os -fno-builtin -fno-common \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -S "$self/daimos-dpy-native-blocks-v1.c" -o "$work/oracle.s"
{
        printf '%s\n' '.equ DPY_TEXT_ROWS,052'
        cat "$DAIMOS_REPO/system/kernel/drivers/dpy_text_blocks_pdp6.s"
} > "$work/dpy_text_blocks.s"

PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
    --start 1000 --step-limit 2000000 --timeout 20 \
    --workdir "$work/run" --name daimos-dpy-native-blocks-v1 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/oracle.s" \
    "$work/dpy_text_blocks.s" >/dev/null

printf '%s\n' \
    'dpy-native-blocks: PASS (simple/complex edits, stale clear, uppercase, ring wrap)'
