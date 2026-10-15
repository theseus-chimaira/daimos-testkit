#!/bin/sh
set -eu
ROOT=${DAIMOS_ROOT:-$HOME/git/DAIMOS}
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
OUT=$(mktemp "$TMPDIR/vfs-mount-slab-v4.XXXXXX")
trap 'rm -f "$OUT"' EXIT HUP INT TERM
${CC:-cc} -std=c99 -Wall -Wextra -Werror \
    -I"$ROOT/system/kernel/boot" -I"$ROOT/system/kernel/fs" \
    -I"$ROOT/system/kernel/core" -I"$ROOT/system/kernel/mm" \
    "$ROOT/system/kernel/boot/vfs_mount_slab_v4.c" \
    "$ROOT/system/kernel/fs/vfs_mount_layout_v3.c" \
    "$(dirname "$0")/test.c" -o "$OUT"
"$OUT"
echo 'vfs-mount-slab-v4: PASS'
