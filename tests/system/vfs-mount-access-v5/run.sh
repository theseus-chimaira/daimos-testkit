#!/bin/sh
set -eu
ROOT=${DAIMOS_ROOT:-$HOME/git/DAIMOS}
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
OUT=$(mktemp "$TMPDIR/vfs-mount-access-v5.XXXXXX")
trap 'rm -f "$OUT"' EXIT HUP INT TERM
das -O "$OUT" "$ROOT/system/kernel/fs/vfs_mount_access_v5.s"
test -s "$OUT"
echo 'vfs-mount-access-v5: DAS PASS (runtime not executed)'
