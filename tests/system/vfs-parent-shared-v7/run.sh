#!/bin/sh
set -eu
ROOT=${DAIMOS_ROOT:-$HOME/git/DAIMOS}
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
OUT=$(mktemp "$TMPDIR/vfs-parent-shared-v7.XXXXXX")
trap 'rm -f "$OUT"' EXIT HUP INT TERM
das -C -O "$OUT" "$ROOT/system/kernel/fs/vfs.s"
test -s "$OUT"
echo 'vfs-parent-shared-v7: relocatable DAS PASS (boot pending)'
