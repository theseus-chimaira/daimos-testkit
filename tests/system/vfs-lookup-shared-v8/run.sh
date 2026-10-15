#!/bin/sh
set -eu
ROOT=${DAIMOS_ROOT:-$HOME/git/DAIMOS}
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
OUT=$(mktemp "$TMPDIR/vfs-lookup-shared-v8.XXXXXX")
trap 'rm -f "$OUT"' EXIT HUP INT TERM
das -C -O "$OUT" "$ROOT/system/kernel/fs/vfs.s"
test -s "$OUT"
echo 'vfs-lookup-shared-v8: relocatable DAS PASS (native execution pending)'
