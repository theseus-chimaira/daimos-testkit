#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work="$TMPDIR/daimos-testkit-memfs-fifo-pdp6-v1-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
p10run="$PDP10_PREFIX/bin/p10run"
kernel="$DAIMOS_REPO/system/kernel"
inc="$kernel/fs"
mm="$kernel/mm"
storage="$kernel/storage"

"$cc" -std=c99 -Os -I"$PDP10_PREFIX/include" -I"$inc" -I"$mm" -I"$storage" -I"$kernel/core" -S "$here/test.c" -o "$work/test.s"
PDP10_PREFIX="$PDP10_PREFIX" "$p10run" \
    --machine pdp6 --mode deposit --exec-mode go --timeout 10 \
    --workdir "$work/run" --name daimos-memfs-fifo-pdp6-v1 \
    --expect daimos_memfs_fifo_pdp6_result=0 --report "$work/report.txt" \
    "$here/start.s" "$work/test.s" "$inc/memfs_runtime.s" \
    "$here/fs-helpers.s" "$kernel/core/ret.s"
echo "PASS daimos-memfs-fifo-pdp6-v1 on pdp6"
