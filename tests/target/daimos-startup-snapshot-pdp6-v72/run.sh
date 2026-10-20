#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work="$TMPDIR/daimos-startup-snapshot-pdp6-v72-$$"
kernel="$DAIMOS_REPO/system/kernel"
gcc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
kcc="$PDP10_PREFIX/bin/kcc"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM

for compiler in gcc kcc; do
    for source in "$here/test.c" "$kernel/proc/proc_startup_snapshot_v72.c"; do
        name=$(basename "$source" .c)
        if [ "$compiler" = kcc ]; then
            "$kcc" -Pgnu99 -O -x=pdp6 -m=gas \
                -I"$PDP10_PREFIX/include" \
                -I"$kernel/core" -I"$kernel/drivers" -I"$kernel/fs" \
                -I"$kernel/mm" -I"$kernel/proc" -I"$kernel/storage" \
                -S "$source" -o "$work/$compiler-$name.s"
        else
            "$gcc" -std=c99 -Os -I"$PDP10_PREFIX/include" \
                -I"$kernel/core" -I"$kernel/drivers" -I"$kernel/fs" \
                -I"$kernel/mm" -I"$kernel/proc" -I"$kernel/storage" \
                -S "$source" -o "$work/$compiler-$name.s"
        fi
    done

    PDP10_PREFIX="$PDP10_PREFIX" "$PDP10_PREFIX/bin/p10run" \
        --machine pdp6 --mode deposit --exec-mode go --timeout 12 \
        --workdir "$work/run-$compiler" --name "daimos-startup-snapshot-pdp6-v72-$compiler" \
        --expect daimos_snap_result_v72=0 --report "$work/report-$compiler.txt" \
        "$here/start.s" "$work/$compiler-test.s" \
        "$work/$compiler-proc_startup_snapshot_v72.s"
done

printf '%s\n' 'daimos-startup-snapshot-pdp6-v72: PASS GCC+KCC (copy/rebase, swapped retention, release, invalid metadata and memory pressure)'
