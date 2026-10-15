#!/bin/sh
set -eu
ROOT=${DAIMOS_ROOT:-$HOME/git/DAIMOS}
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
OUT=$(mktemp "$TMPDIR/vfs-parent-mount-v6.XXXXXX")
trap 'rm -f "$OUT"' EXIT HUP INT TERM
das -O "$OUT" "$ROOT/system/kernel/fs/vfs_parent_mount_v6.s"
test -s "$OUT"
echo 'vfs-parent-mount-v6: DAS PASS (native execution pending)'
