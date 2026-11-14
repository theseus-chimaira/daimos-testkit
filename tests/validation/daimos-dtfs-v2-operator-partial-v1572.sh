#!/bin/sh
# v1572: production V2/CLEAN RW -> real Type-551 one-word DATA fault,
# sticky poisoned mount -> independent production cold-boot refusal.
# Trusted operator does not change the reel while a mount is live.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-v2-operator-partial-v1572.XXXXXX")
if [ "${V1572_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1572 DATA fault evidence: $work"
fi

export DAIMOS_TSFS_PREBUILT_BUILD="${DAIMOS_V1572_BASE_BUILD:-$work/production-image}"
if [ -z "${DAIMOS_V1572_BASE_BUILD:-}" ]; then
    PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" \
        image BUILD="$DAIMOS_TSFS_PREBUILT_BUILD" \
        USERLAND_BUILD_ROOT="$DAIMOS_TSFS_PREBUILT_BUILD" \
        ROOT=tape BOOT=ptr PDP10_PREFIX="$PDP10_PREFIX" \
        PROC_BOOT_USERS=1 HOST_TOOLS="$PDP10_PREFIX/bin" \
        > "$work/build-v1572.log" 2>&1 || {
        tail -75 "$work/build-v1572.log" >&2
        exit 1
    }
fi

export DAIMOS_TSFS_SIMH="${DAIMOS_TSFS_SIMH:-$PDP10_PREFIX/bin/pdp6-v1529r5}"
export DAIMOS_TSFS_GATE_DTVOL2_V1564=1
export DAIMOS_TSFS_GATE_PARTIAL_V1529=1
export DAIMOS_TSFS_GATE_PARTIAL_V2_DATA_V1568=1
export DAIMOS_TSFS_GATE_EXPORT_DATA_V1568="$work/real-dirty-failed-v1572.tap"
export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-partial-write-v1529.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSPART V1529'
export DAIMOS_TSFS_GATE_STAGES_V1526='START SEED_TRUNCATE_OK READY_ARM WRITE_FAILED READY_VERIFY STICKY_CONFIRMED PASS'
echo 'v1572: production V2 RW actual physical partial DATA/poison'
sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
test -s "$DAIMOS_TSFS_GATE_EXPORT_DATA_V1568"

unset DAIMOS_TSFS_GATE_PARTIAL_V1529
unset DAIMOS_TSFS_GATE_PARTIAL_V2_DATA_V1568
unset DAIMOS_TSFS_GATE_EXPORT_DATA_V1568
export DAIMOS_TSFS_GATE_V2_REPLAY_DIRTY_V1568="$work/real-dirty-failed-v1572.tap"
export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-v2-dirty-gate-v1564.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSV2DIRTY V1564'
export DAIMOS_TSFS_GATE_STAGES_V1526='START RW_REFUSED RO_REFUSED UNPUBLISHED PASS'
echo 'v1572: second wholly production cold boot exact damaged V2/DIRTY'
sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
echo 'PASS v1572: production V2 DATA fault/poison and cold boot'
