#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
d6fs_source="$DAIMOS_REPO/system/kernel/fs/d6fs_runtime.s"
vfs_source="$DAIMOS_REPO/system/kernel/fs/vfs.s"
work="$TMPDIR/daimos-d6fs-remount-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

# Extract the production D6FS context selector plus the remount/unmount state
# transition body.  Mount creation and the normal provider vector are supplied
# by the oracle because this test targets A/B publication and lifecycle only.
{
        echo '.text'
        echo '.globl d6fs_mres_dispatch'
        sed -n '/^d6fs_mres_dispatch:/,/^        \.globl  vfs_mount_prevalidated$/p' "$d6fs_source" |
                sed '$d'
        sed -n '/^d6fs_provider_toggle_state:/,/^        \.globl  pclk_time36$/p' "$d6fs_source" |
                sed '$d'
} > "$work/d6fs-remount.s"

# Extract the tiny production kernel remount veneer.
{
        echo '.text'
        echo '.globl vfs_remount'
        sed -n '/^vfs_remount:/,/^; int vfs_unmount(root)$/p' "$vfs_source" |
                sed '$d'
} > "$work/vfs-remount.s"

PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
        --start 1000 --step-limit 1000000 --timeout 15 \
        --workdir "$work/run" --name daimos-d6fs-remount-v1 \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-d6fs-remount-v1.s" \
        "$work/d6fs-remount.s" "$work/vfs-remount.s" >/dev/null

printf '%s\n' 'd6fs-remount: PASS (RW/RO A/B publication, failure atomicity, unmount cleanup)'
