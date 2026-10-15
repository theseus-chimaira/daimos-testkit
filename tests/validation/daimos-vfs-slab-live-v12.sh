#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
source_file="$DAIMOS_REPO/system/kernel/fs/vfs.s"
work="$TMPDIR/daimos-vfs-slab-live-v12-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

{
        echo '.text'
        echo '.globl vfs_storage_release'
        echo '.globl vfs_mount'
        echo '.globl vfs_unmount'
        sed -n '/^vfs_storage_release:/,/^        \.data$/p' "$source_file" | sed '$d'
} > "$work/vfs-mutation.s"

PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
        --start 1000 --step-limit 1000000 --timeout 15 \
        --workdir "$work/run" --name daimos-vfs-slab-live-v12 \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-vfs-slab-live-v12.s" \
        "$work/vfs-mutation.s" >/dev/null

printf '%s\n' 'vfs-slab-live-v12: PASS (switched MM-style bases, reservation, retirement, reuse)'
