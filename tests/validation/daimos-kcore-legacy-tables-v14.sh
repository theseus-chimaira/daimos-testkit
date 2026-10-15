#!/bin/sh
# Build resident low-memory KCORE only, and assert the obsolete VFS/D6FS
# fallback arrays are absent from the *linked* permanent symbol table.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-kcore-legacy-tables-v14.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
if ! make -C "$DAIMOS_REPO/system/boot/pdp6" permanent-size \
    ROOT=disk BOOT=dsk BOOT_PROFILE=lowmem COMPILER=gcc \
    PDP10_PREFIX="$PDP10_PREFIX" BUILD_ROOT="$work/build" \
    >"$work/build.log" 2>&1; then
    tail -35 "$work/build.log" >&2
    exit 1
fi
map="$work/build/system/boot/pdp6/kcore.map"
for old in vfs_mount_target vfs_mount_root d6fs_reader_slots; do
    if awk -v symbol="$old" '$1 == symbol { found = 1 } END { exit !found }' "$map"; then
        echo "obsolete KCORE symbol remains: $old" >&2
        exit 1
    fi
done
for live in vfs_mount_target_base vfs_mount_root_base \
    d6fs_reader_slots_base d6fs_active_reader; do
    if ! awk -v symbol="$live" '$1 == symbol { found = 1 } END { exit !found }' "$map"; then
        echo "missing live KCORE symbol: $live" >&2
        exit 1
    fi
done
end=$(awk '$1 == "__kcore_low_end" { print $2 }' "$map")
case "$end" in ''|*[!0-7]*) echo 'invalid KCORE end' >&2; exit 1 ;; esac
printf 'kcore-legacy-tables-v14: PASS (no legacy arrays; KCORE_END=%s)\n' "$end"
