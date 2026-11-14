#!/bin/sh
# Real PDP-6 Type-551 physical DIRTY arm then production CLEAN/unmount.
# Production v1555 DTVOL2 RO veto remains UNCHANGED: this test modifies
# ONLY a disposable compiled KCORE/MRES copy, never a source checkout.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-clean-physical-v1566.XXXXXX")
if [ "${V1566_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1566: keeping disposable physical CLEAN guest: $work"
fi

base=${DAIMOS_V1566_BASE_BUILD:-}
if [ -z "$base" ]; then
    base="$work/production-image"
    echo 'v1566: building separate source-matched production KCC image'
    PATH="$PDP10_PREFIX/bin:$PATH" make \
        -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$base" USERLAND_BUILD_ROOT="$base" \
        ROOT=tape BOOT=ptr PDP10_PREFIX="$PDP10_PREFIX" \
        PROC_BOOT_USERS=1 HOST_TOOLS="$PDP10_PREFIX/bin" \
        > "$work/base-build-v1566.log" 2>&1 || {
        tail -90 "$work/base-build-v1566.log" >&2
        exit 1
    }
fi
test -f "$base/boot.ini" && test -f "$base/kcore-asm/vfs.s" && \
    test -f "$base/kcore-asm/dtfs_runtime.s" && \
    test -f "$base/dtfs-mres.map" || {
    echo 'v1566: a full matching 256K KCC physical base image is required' >&2
    exit 1
}
build="$work/guest-build"
mkdir -p "$build"
cp -a "$base/." "$build/"

python3 - "$DAIMOS_REPO" "$self" "$build" <<'PY'
from pathlib import Path
import sys
repo,self,build=(Path(x) for x in sys.argv[1:])
vfs=(repo/'system/kernel/fs/vfs.s').read_text()
vfs_target=build/'kcore-asm/vfs.s'
assert vfs_target.read_text()==vfs, 'VFS base build is stale or foreign'
anchor=('        movem   1,-2(17)               ; 1 for V2, zero otherwise\n'
        '        move    1,-1(17)\n'
        '        pushj   17,vfs_sync\n')
assert vfs.count(anchor)==1
insert=('        movem   1,-2(17)               ; 1 for V2, zero otherwise\n'
        '        ; v1566 TEST ONLY: physically arm this one mounted DTC3\n'
        '        ; through real MM/Type-551 before unchanged CLEAN path.\n'
        '        skipn   -2(17)\n'
        '        jrst    vfs_test_arm_done_v1566\n'
        '        move    1,(17)\n'
        '        move    2,-1(17)\n'
        '        movei   6,030           ; TEST ONLY private MRES op\n'
        '        movei   7,5\n'
        '        pushj   17,fs_provider_reg_call\n'
        '        jumpn   1,vfs_unmount_fail\n'
        '        .globl vfs_test_arm_done_v1566\n'
        'vfs_test_arm_done_v1566:\n'
        '        move    1,-1(17)\n'
        '        pushj   17,vfs_sync\n')
vfs_target.write_text(vfs.replace(anchor,insert,1))

file_names=('dtfs_runtime.s','dtfs_intent_validate_v1550.s',
            'dtfs_v2_mount_exclusive_v1557.s',
            'dtfs_intent_mount_gate_v1561.s',
            'dtfs_intent_first_write_v1553.s',
            'dtfs_intent_owned_arm_v1552.s',
            'dtfs_intent_arm_v1551.s',
            'dtfs_intent_verify_v1554.s',
            'dtfs_intent_clean_v1566.s',
            'dtfs_intent_mount_seal_v1566.s')
source=('.set DTFS_ENABLE_TENEX,0\n'
        '.set DTFS_ENABLE_ITS,0\n'
        '.set DTFS_ENABLE_FOREIGN,0\n'+
        ''.join((repo/'system/kernel/fs'/name).read_text() for name in
                file_names))
dtfs_target=build/'kcore-asm/dtfs_runtime.s'
assert dtfs_target.read_text()==source, (
    'DTFS MRES base build is stale, or production source differs')
key='dtfs_mres_reg_dispatch:\n'
assert source.count(key)==1
dispatch=(key+
          '        ; v1566 DISPOSABLE physical proof, NEVER production\n'
          '        cain    6,030\n'
          '        jrst    dtfs_test_physical_arm_v1566\n')
test_arm=(self/'daimos-dtfs-clean-physical-arm-v1566.s').read_text()
dtfs_target.write_text(source.replace(key,dispatch,1)+'\n'+test_arm)
assert 'v1555' in source and 'dtfs_v2_ro_write_guard_v1555' in source
print('PASS v1566: isolated source-matched test-only physical arm linked')
PY

echo 'v1566: rebuilding TEST-ONLY VFS/MRES and physical boot image'
PATH="$PDP10_PREFIX/bin:$PATH" make \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" USERLAND_BUILD_ROOT="$build" \
    ROOT=tape BOOT=ptr PDP10_PREFIX="$PDP10_PREFIX" \
    PROC_BOOT_USERS=1 HOST_TOOLS="$PDP10_PREFIX/bin" \
    > "$work/image-build-v1566.log" 2>&1 || {
    tail -100 "$work/image-build-v1566.log" >&2
    exit 1
}
grep -q 'vfs_test_arm_done_v1566' "$build/kcore.map" || {
    echo 'FAIL v1566: test-only VFS arm not in KCORE map' >&2
    exit 1
}
grep -q 'dtfs_test_physical_arm_v1566' "$build/dtfs-mres.map" || {
    echo 'FAIL v1566: test-only physical arm not in DTFS MRES map' >&2
    exit 1
}
grep -q 'dtfs_intent_mount_seal_v1566' "$build/dtfs-mres.map" || {
    echo 'FAIL v1566: production CLEAN provider missing' >&2
    exit 1
}

export DAIMOS_TSFS_PREBUILT_BUILD="$build"
export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-cross-owner-v1526.c"
export DAIMOS_TSFS_GATE_DTVOL2_V1564=1
export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSV2 V1564'
export DAIMOS_TSFS_GATE_STAGES_V1526='START RW_REFUSED MOUNTED CROSS_CWD_REFUSED CROSS_FILE_REFUSED CROSS_RETIRED REMOUNTED PASS'
echo 'v1566: real Type-551 DIRTY arm -> CLEAN readback twice in PDP-6 guest'
sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
echo 'PASS v1566: physical DTVOL2 DIRTY->CLEAN under exclusive owner seal'
