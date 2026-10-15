#!/bin/sh
set -eu
ROOT=${DAIMOS_ROOT:-$HOME/git/DAIMOS}
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
OUT=$(mktemp "$TMPDIR/vfs-mount-layout-v3.XXXXXX")
trap 'rm -f "$OUT"' EXIT HUP INT TERM
${CC:-cc} -std=c99 -Wall -Wextra -Werror \
    -I"$ROOT/system/kernel/fs" -I"$ROOT/system/kernel/core" \
    "$ROOT/system/kernel/fs/vfs_mount_layout_v3.c" \
    "$(dirname "$0")/test.c" -o "$OUT"
"$OUT"
echo 'vfs-mount-layout-v3: PASS'
