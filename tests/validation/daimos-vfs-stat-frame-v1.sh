#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
kernel="$DAIMOS_REPO/system/kernel"
work="$TMPDIR/daimos-vfs-stat-frame-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=c99 -Os -fno-builtin \
        -fno-common -march=pdp6 -I"$kernel/core" -I"$kernel/fs" \
        -I"$kernel/storage" -S \
        "$self/daimos-vfs-stat-frame-v1.c" -o "$work/test.s"

PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
        --start 1000 --step-limit 1000000 --timeout 15 \
        --workdir "$work/run" --name daimos-vfs-stat-frame-v1 \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" "$work/test.s" \
        "$kernel/fs/vfs.s" "$kernel/drivers/device_state.s" \
        "$kernel/core/ret.s" \
        "$self/daimos-vfs-stat-frame-stubs-v1.s" >/dev/null

printf '%s\n' 'daimos-vfs-stat-frame-v1: PASS (six-word STAT locals preserve return stack)'
