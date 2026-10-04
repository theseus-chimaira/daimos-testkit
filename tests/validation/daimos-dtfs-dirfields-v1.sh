#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-dtfs-dirfields-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=c99 -Os -fno-builtin -fno-common \
    -march=pdp6 -I"$DAIMOS_REPO/system/kernel/core" \
    -S "$self/daimos-dtfs-dirfields-v1.c" -o "$work/oracle.s"

{
    printf '%s\n' '.text'
    awk '/^[[:space:]]*\.globl[[:space:]]+dtfs_clear_slot$/ {copy=1} /^dtfs_restore4:$/ {copy=0} copy {print}' \
        "$DAIMOS_REPO/system/kernel/fs/dtfs_runtime.s"
} > "$work/dirfields.s"

PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
    --start 1000 --step-limit 1000000 --timeout 20 \
    --workdir "$work/run" --name daimos-dtfs-dirfields-v1 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/oracle.s" "$work/dirfields.s" >/dev/null
printf '%s\n' 'dtfs-dirfields: PASS (clear slot, last-word count, executable bit)'
