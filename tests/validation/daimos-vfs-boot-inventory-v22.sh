#!/bin/sh
# Use the production C99 root selector and capacity planner in both native
# PDP-6 boot profiles. The full fixture models selected physical membership;
# driver probes themselves are replaced by explicit test handoffs.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-vfs-boot-inventory-v22.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
for profile in full disk; do
    if [ "$profile" = full ]; then
        opts='-DKINIT_FULL=1 -DKINIT_TAPE_BOOT=1'
    else
        opts='-DKINIT_FULL=0 -DKINIT_TAPE_BOOT=0'
    fi
    for src in "$self/daimos-vfs-boot-inventory-v22.c" \
        "$DAIMOS_REPO/system/kernel/boot/root_select.c" \
        "$DAIMOS_REPO/system/kernel/boot/vfs_mount_capacity_v1.c"; do
        stem=$(basename "$src" .c)
        "$cc" -std=c99 -Os $opts -DD6FS_FS_ENABLED=1 \
            -I"$DAIMOS_REPO/system/kernel/core" \
            -I"$DAIMOS_REPO/system/kernel/boot" \
            -I"$DAIMOS_REPO/system/kernel/fs" \
            -I"$DAIMOS_REPO/system/kernel/storage" \
            -I"$DAIMOS_REPO/system/kernel/drivers" \
            -I"$DAIMOS_REPO/system/kernel/modules" \
            -S "$src" -o "$work/$stem.s"
    done
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 180000 --timeout 15 \
        --workdir "$work/run-$profile" --name "daimos-vfs-inventory-v22-$profile" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$work/daimos-vfs-boot-inventory-v22.s" \
        "$work/root_select.s" "$work/vfs_mount_capacity_v1.s" >/dev/null
    echo "vfs-boot-inventory-v22: $profile PASS (selected members and dynamic capacity)"
done
