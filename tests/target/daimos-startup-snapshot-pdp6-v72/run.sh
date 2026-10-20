#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work="$TMPDIR/daimos-startup-snapshot-pdp6-v72-$$"
kernel="$DAIMOS_REPO/system/kernel"
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM

for source in "$here/test.c" "$kernel/proc/proc_startup_snapshot_v72.c"; do
    name=$(basename "$source" .c)
    "$cc" -std=c99 -Os -I"$PDP10_PREFIX/include" \
        -I"$kernel/core" -I"$kernel/drivers" -I"$kernel/fs" \
        -I"$kernel/mm" -I"$kernel/proc" -I"$kernel/storage" \
        -S "$source" -o "$work/$name.s"
done

PDP10_PREFIX="$PDP10_PREFIX" "$PDP10_PREFIX/bin/p10run" \
    --machine pdp6 --mode deposit --exec-mode go --timeout 12 \
    --workdir "$work/run" --name daimos-startup-snapshot-pdp6-v72 \
    --expect daimos_snap_result_v72=0 --report "$work/report.txt" \
    "$here/start.s" "$work/test.s" \
    "$work/proc_startup_snapshot_v72.s"

printf '%s\n' 'daimos-startup-snapshot-pdp6-v72: PASS (copy/rebase, swapped retention, release, invalid metadata and memory pressure)'
