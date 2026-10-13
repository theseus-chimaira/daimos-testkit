#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR/d6codec-tsfs-v075-test"
inc="-I$DAIMOS_REPO/system/kernel -I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/ipc -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules -I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage -I$DAIMOS_REPO/userland/libc -I$DAIMOS_REPO/userland/tsfs -I$PDP10_PREFIX/include"
# Intentional unquoted expansion of the project-controlled include arguments.
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=gnu99 -Os -march=pdp6 -mcpu=pdp6 $inc -S -o "$TMPDIR/d6codec-tsfs-v075-test/scan-v075.s" "$DAIMOS_REPO/userland/tsfs/tsfs_scan_inline_v075.c"
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=gnu99 -Os -march=pdp6 -mcpu=pdp6 -DKINIT_TAPE_BOOT=1 $inc -S -o "$TMPDIR/d6codec-tsfs-v075-test/boot-v075.s" "$DAIMOS_REPO/system/kernel/boot/tsfs_boot_inline_v075.c"
test -s "$TMPDIR/d6codec-tsfs-v075-test/scan-v075.s"
test -s "$TMPDIR/d6codec-tsfs-v075-test/boot-v075.s"
printf '%s\n' 'PASS v075 two TSFS 1.3 validators compile for PDP-6'
