#!/bin/sh
# Real physical Type-551 cold boot after 36-bit on-media torn transactions.
# Uses production KCORE and v1555 DTVOL2 read-only gate unchanged. The
# fault records are created on a disposable host tape BEFORE guest boot.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-v2-fault-v1567.XXXXXX")
if [ "${V1567_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

if [ -z "${DAIMOS_TSFS_PREBUILT_BUILD:-}" ]; then
    export DAIMOS_TSFS_PREBUILT_BUILD="$work/guest-build"
    echo 'v1567: build independent current 256K KCC production image'
    PATH="$PDP10_PREFIX/bin:$PATH" make \
        -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$DAIMOS_TSFS_PREBUILT_BUILD" \
        USERLAND_BUILD_ROOT="$DAIMOS_TSFS_PREBUILT_BUILD" \
        ROOT=tape BOOT=ptr PDP10_PREFIX="$PDP10_PREFIX" \
        PROC_BOOT_USERS=1 HOST_TOOLS="$PDP10_PREFIX/bin" \
        > "$work/image-build-v1567.log" 2>&1 || {
        tail -95 "$work/image-build-v1567.log" >&2
        exit 1
    }
fi

test -f "$DAIMOS_TSFS_PREBUILT_BUILD/kcore.map" || {
    echo 'v1567: full 256K KCORE image required' >&2
    exit 1
}
test -f "$DAIMOS_TSFS_PREBUILT_BUILD/kcore-asm/dtfs_runtime.s" || exit 1
# Strong source match for the read-only provider, not just the map name.
python3 - "$DAIMOS_REPO" "$DAIMOS_TSFS_PREBUILT_BUILD" <<'PY'
from pathlib import Path
import sys
repo,b=(Path(x) for x in sys.argv[1:])
names=('dtfs_runtime.s','dtfs_intent_validate_v1550.s',
       'dtfs_v2_mount_exclusive_v1557.s',
       'dtfs_intent_mount_gate_v1561.s',
       'dtfs_intent_first_write_v1553.s',
       'dtfs_intent_owned_arm_v1552.s',
       'dtfs_intent_arm_v1551.s','dtfs_intent_verify_v1554.s',
       'dtfs_intent_clean_v1566.s','dtfs_intent_mount_seal_v1566.s')
expected=('.set DTFS_ENABLE_TENEX,0\n'
          '.set DTFS_ENABLE_ITS,0\n'
          '.set DTFS_ENABLE_FOREIGN,0\n' +
          ''.join((repo/'system/kernel/fs'/n).read_text() for n in names))
assert (b/'kcore-asm/dtfs_runtime.s').read_text()==expected, (
    'v1567 requires exact production DTFS provider source')
assert (b/'kcore-asm/vfs.s').read_text()==(
    repo/'system/kernel/fs/vfs.s').read_text(), (
    'v1567 requires exact production VFS source')
print('PASS v1567: cold boots use unmodified source-matched production VFS/MRES')
PY

export DAIMOS_TSFS_GATE_DTVOL2_V1564=1
unset DAIMOS_TSFS_GATE_V2_DIRTY_V1564

# The final control demonstrates a known limitation: a CLEAN RBN0
# does not have independent checksums for arbitrary DATA blocks.
# It MUST mount read-only; it is NOT proof that corrupted data was fixed.
default_modes='torn-dirty-state torn-dirty-seal torn-clean-state torn-clean-seal torn-clean-half torn-identity torn-magic torn-padding dirty-data-prefix dirty-dir-prefix clean-data-corrupt-control'
for mode in ${V1567_FAULT_MODES:-$default_modes}; do
    case "$mode" in
        torn-dirty-state|torn-dirty-seal|torn-clean-state|torn-clean-seal|\
        torn-clean-half|torn-identity|torn-magic|torn-padding|\
        dirty-data-prefix|dirty-dir-prefix)
            export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-v2-dirty-gate-v1564.c"
            export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSV2DIRTY V1564'
            export DAIMOS_TSFS_GATE_STAGES_V1526='START RW_REFUSED RO_REFUSED UNPUBLISHED PASS'
            ;;
        clean-data-corrupt-control)
            export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-cross-owner-v1526.c"
            export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSV2 V1564'
            export DAIMOS_TSFS_GATE_STAGES_V1526='START RW_REFUSED MOUNTED CROSS_CWD_REFUSED CROSS_FILE_REFUSED CROSS_RETIRED REMOUNTED PASS'
            ;;
        *) echo "v1567: unknown mode $mode" >&2; exit 1 ;;
    esac
    export DAIMOS_TSFS_GATE_V2_FAULT_V1567="$mode"
    echo "v1567: cold boot with physical DTC3 crash image [$mode]"
    sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh" \
        > "$work/$mode.log" 2>&1 || {
        tail -85 "$work/$mode.log" >&2
        echo "FAIL v1567: physical cold boot rejected: $mode" >&2
        exit 1
    }
    grep -q 'daimos-dtfs-secondary-mounted-v1525: PASS' \
        "$work/$mode.log" || {
        tail -50 "$work/$mode.log" >&2
        exit 1
    }
    grep -q 'physical DTVOL2 media unchanged after real guest test' \
        "$work/$mode.log" || {
        echo "FAIL v1567: DTC3 whole-image fingerprint absent: $mode" >&2
        exit 1
    }
    echo "PASS v1567: physically read $mode, guest oracle and tape SHA256"
done
echo 'PASS v1567: booted Type-551 torn DTVOL2 and DATA rejection matrix'
