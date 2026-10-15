#!/bin/sh
set -eu
ROOT=${DAIMOS_ROOT:-$HOME/git/DAIMOS}
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
OUT=$(mktemp "$TMPDIR/vfs-mount-capacity-v1.XXXXXX")
trap 'rm -f "$OUT"' EXIT HUP INT TERM
${CC:-cc} -std=c99 -Wall -Wextra -Werror -I"$ROOT/system/kernel/boot" \
    "$ROOT/system/kernel/boot/vfs_mount_capacity_v1.c" \
    "$(dirname "$0")/test.c" -o "$OUT"
"$OUT"
echo 'vfs-mount-capacity-v1: PASS'
