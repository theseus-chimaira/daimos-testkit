#!/bin/sh
# Production Type-551/CLEAN -> DIRTY writes -> physical CLEAN/unmount;
# fresh production cold boot of exact saved tape. Operator retains reel.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-v2-operator-v1572.XXXXXX")
if [ "${V1572_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1572 evidence: $work"
fi

export DAIMOS_TSFS_PREBUILT_BUILD="${DAIMOS_V1572_BASE_BUILD:-$work/production-image}"
if [ -z "${DAIMOS_V1572_BASE_BUILD:-}" ]; then
    echo 'v1572: building fresh production PDP-6 full KCC image'
    PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" \
        image BUILD="$DAIMOS_TSFS_PREBUILT_BUILD" \
        USERLAND_BUILD_ROOT="$DAIMOS_TSFS_PREBUILT_BUILD" \
        ROOT=tape BOOT=ptr PDP10_PREFIX="$PDP10_PREFIX" \
        PROC_BOOT_USERS=1 HOST_TOOLS="$PDP10_PREFIX/bin" \
        > "$work/build-v1572.log" 2>&1 || {
        tail -85 "$work/build-v1572.log" >&2
        exit 1
    }
fi

grep -q '^dtfs_intent_first_write_v1553 ' \
    "$DAIMOS_TSFS_PREBUILT_BUILD/dtfs-mres.map" &&
grep -q '^dtfs_intent_verify_v1554 ' \
    "$DAIMOS_TSFS_PREBUILT_BUILD/dtfs-mres.map" || {
    echo 'FAIL v1572: first-write / physically verified armed gate absent' >&2
    exit 1
}

export DAIMOS_TSFS_GATE_DTVOL2_V1564=1
export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-v2-operator-rw-v1572.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSOP V1572'
export DAIMOS_TSFS_GATE_STAGES_V1526='START RW_MOUNTED DIRTY_WRITES READBACK CLEAN_UNMOUNT RO_REMOUNT PASS'
export DAIMOS_TSFS_GATE_EXPORT_CLEAN_V1572="$work/production-clean-v1572.tap"
echo 'v1572: physical production RW, first DIRTY arm, repeated DATA, CLEAN'
sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
test -s "$DAIMOS_TSFS_GATE_EXPORT_CLEAN_V1572"

unset DAIMOS_TSFS_GATE_EXPORT_CLEAN_V1572
export DAIMOS_TSFS_GATE_V2_REPLAY_CLEAN_V1570="$work/production-clean-v1572.tap"
export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-v2-operator-reboot-v1572.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSBOOT V1572'
export DAIMOS_TSFS_GATE_STAGES_V1526='START READBACK PASS'
echo 'v1572: entirely production second cold boot, original saved V2/CLEAN'
sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
echo 'PASS v1572: operator-trust production V2 RW/CLEAN and cold boot'
