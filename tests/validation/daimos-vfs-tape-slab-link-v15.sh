#!/bin/sh
# Link the real tape-root KCORE and DTFS MRES without userland or shell boot.
# The obsolete DTFS/TSFS four-entry tables must not be retained anywhere.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-vfs-tape-slab-link-v15.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
if ! make -C "$DAIMOS_REPO/system/boot/pdp6" permanent-size \
    ROOT=tape BOOT=dtc PDP10_PREFIX="$PDP10_PREFIX" \
    BUILD_ROOT="$work/build" >"$work/build.log" 2>&1; then
    tail -35 "$work/build.log" >&2
    exit 1
fi
dir="$work/build/system/boot/pdp6"
for map in "$dir/kcore.map" "$dir/dtfs-mres.map"; do
    for obsolete in dtfs_media tsfs_file_shape tsfs_extent_media; do
        if awk -v n="$obsolete" '$1==n {seen=1} END {exit !seen}' "$map"; then
            echo "obsolete metadata table in $(basename "$map"): $obsolete" >&2
            exit 1
        fi
    done
done
for live in dtfs_media_base tsfs_file_shape_base tsfs_extent_media_base; do
    if ! awk -v n="$live" '$1==n {seen=1} END {exit !seen}' "$dir/kcore.map"; then
        echo "missing KCORE slab pointer: $live" >&2
        exit 1
    fi
done
grep -E '^KCORE\+MRES|^PERMANENT_LAST' "$work/build.log"
echo 'vfs-tape-slab-link-v15: PASS (all three arrays removed; shared MM bases linked)'
