#!/bin/sh
# Real PDP-6/Type-551, production trusted-operator V2 poisoned discard.
# Provider lease drains in-flight I/O; no physical replacement verifier.
# Old DTVOL2/DIRTY is rejected by normal MOUNT even after owner discard.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-operator-discard-v1575.XXXXXX")
if [ "${V1575_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1575 evidence: $work"
fi
export DAIMOS_TSFS_PREBUILT_BUILD="${DAIMOS_V1575_BASE_BUILD:-$work/production-image}"
if [ -z "${DAIMOS_V1575_BASE_BUILD:-}" ]; then
    PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" \
        image BUILD="$DAIMOS_TSFS_PREBUILT_BUILD" \
        USERLAND_BUILD_ROOT="$DAIMOS_TSFS_PREBUILT_BUILD" \
        ROOT=tape BOOT=ptr PDP10_PREFIX="$PDP10_PREFIX" \
        PROC_BOOT_USERS=1 HOST_TOOLS="$PDP10_PREFIX/bin" \
        > "$work/build-v1575.log" 2>&1 || {
        tail -75 "$work/build-v1575.log" >&2
        exit 1
    }
fi
if grep -q '^dtfs_verify_replacement_v1531 ' \
    "$DAIMOS_TSFS_PREBUILT_BUILD/dtfs-mres.map"; then
    echo 'FAIL v1575: obsolete physical replacement verifier still linked' >&2
    exit 1
fi
grep -q '^dtfs_discard_drain_v1575 ' \
    "$DAIMOS_TSFS_PREBUILT_BUILD/dtfs-mres.map"

export DAIMOS_TSFS_SIMH="${DAIMOS_TSFS_SIMH:-$PDP10_PREFIX/bin/pdp6-v1529r5}"
export DAIMOS_TSFS_GATE_DTVOL2_V1564=1
export DAIMOS_TSFS_GATE_PARTIAL_V1529=1
export DAIMOS_TSFS_GATE_PARTIAL_V2_DATA_V1568=1
export DAIMOS_TSFS_GATE_PARTIAL_V2_ADMIN_V1575=1
export DAIMOS_TSFS_GATE_EXPORT_DATA_V1568="$work/original-dirty-v1575.tap"
export DAIMOS_TSFS_GATE_EXPORT_REPLACE_V1570="$work/replacement-clean-v1575.tap"
export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-v2-operator-discard-v1575.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSV2ADM V1575'
export DAIMOS_TSFS_GATE_STAGES_V1526='START READY_ARM WRITE_FAILED READY_VERIFY DISCARDED_DIRTY READY_REPLACE RETIRED PASS'

echo 'v1575: real physical partial DATA, owner release, same-DIRTY refusal'
sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
test -s "$work/original-dirty-v1575.tap"
test -s "$work/replacement-clean-v1575.tap"

unset DAIMOS_TSFS_GATE_PARTIAL_V1529
unset DAIMOS_TSFS_GATE_PARTIAL_V2_DATA_V1568
unset DAIMOS_TSFS_GATE_PARTIAL_V2_ADMIN_V1575
unset DAIMOS_TSFS_GATE_EXPORT_DATA_V1568
unset DAIMOS_TSFS_GATE_EXPORT_REPLACE_V1570
export DAIMOS_TSFS_GATE_V2_REPLAY_DIRTY_V1568="$work/original-dirty-v1575.tap"
export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-v2-dirty-gate-v1564.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSV2DIRTY V1564'
export DAIMOS_TSFS_GATE_STAGES_V1526='START RW_REFUSED RO_REFUSED UNPUBLISHED PASS'
echo 'v1575: independent production cold boot rejects damaged DIRTY reel'
sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
echo 'PASS v1575: production operator-trust discard, fresh mount and cold-boot refusal'
