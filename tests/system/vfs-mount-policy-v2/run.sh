#!/bin/sh
set -eu
ROOT=${DAIMOS_ROOT:-$HOME/git/DAIMOS}
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
OUT=$(mktemp "$TMPDIR/vfs-mount-policy-v2.XXXXXX")
trap 'rm -f "$OUT"' EXIT HUP INT TERM
${CC:-cc} -std=c99 -Wall -Wextra -Werror -I"$ROOT/system/kernel/fs" \
    -I"$ROOT/system/kernel/core" -I"$ROOT/system/kernel/storage" \
    -I"${PDP10_PREFIX:-$HOME/cross}/include" \
    "$ROOT/system/kernel/fs/vfs_mount_policy_v2.c" \
    "$(dirname "$0")/test.c" -o "$OUT"
"$OUT"
echo 'vfs-mount-policy-v2: PASS'
