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
import os
if os.environ.get('V1567_PHYSICAL_CLEAN_PARTIAL') == '1':
    # v1567 DISPOSABLE TEST ONLY: the first unmount physically arms
    # DIRTY using the genuine provider and fails before the final
    # CLEAN; the second unmount uses unchanged production v1566 seal.
    # Two exact KCORE breakpoints in this copied image provide a
    # deterministic simulator stop, never an asynchronous CTRL-E race.
    insert=(
        '        movem   1,-2(17)               ; 1 for V2, zero otherwise\n'
        '        skipn   -2(17)\n'
        '        jrst    vfs_test_arm_done_v1566\n'
        '        move    1,dtfs_media_base\n'
        '        add     1,(17)\n'
        '        move    3,(1)\n'
        '        trne    3,0040000       ; DIRTY already armed: retry CLEAN\n'
        '        jrst    vfs_test_arm_done_v1566\n'
        '        move    1,(17)\n'
        '        move    2,-1(17)\n'
        '        movei   6,030           ; TEST ONLY raw physical DIRTY\n'
        '        movei   7,5\n'
        '        pushj   17,fs_provider_reg_call\n'
        '        jumpn   1,vfs_unmount_fail\n'
        '        ; Leave first real DIRTY transaction mounted, no CLEAN.\n'
        '        jrst    vfs_unmount_fail\n'
        '        .globl vfs_test_arm_done_v1566\n'
        'vfs_test_arm_done_v1566:\n'
        '        move    1,-1(17)\n'
        '        pushj   17,vfs_sync\n')
vfs_injected = vfs.replace(anchor,insert,1)
if os.environ.get('V1567_PHYSICAL_CLEAN_PARTIAL') == '1':
    before_clean=('        movei   6,027                   ; private DTFS SEAL_CLEAN_V1566\n'
                  '        movei   7,5                     ; DTFS_PROVIDER\n'
                  '        pushj   17,fs_provider_reg_call\n')
    assert vfs_injected.count(before_clean)==1
    vfs_injected=vfs_injected.replace(before_clean,
        before_clean.replace('        pushj   17,fs_provider_reg_call\n',
        '        .globl vfs_test_before_clean_v1567\n'
        'vfs_test_before_clean_v1567:\n'
        '        pushj   17,fs_provider_reg_call\n'),1)
    failed_clean=('        trne    3,0400000              ; partial/ambiguous physical CLEAN\n'
                  '        jrst    vfs_unmount_fail_done_v1562\n')
    assert vfs_injected.count(failed_clean)==1
    vfs_injected=vfs_injected.replace(failed_clean,
        failed_clean.replace('        jrst    vfs_unmount_fail_done_v1562\n',
        '        jrst    vfs_test_after_failed_clean_v1567\n'),1)
    failed_exit=('vfs_unmount_fail_done_v1562:\n'
                 '        sub     17,kconst_3_3\n'
                 '        jrst    kret_neg1\n')
    assert vfs_injected.count(failed_exit)==1
    vfs_injected=vfs_injected.replace(failed_exit,
        failed_exit+
        '        .globl vfs_test_after_failed_clean_v1567\n'
        'vfs_test_after_failed_clean_v1567:\n'
        '        jrst    vfs_unmount_fail_done_v1562\n',1)
vfs_target.write_text(vfs_injected)

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
if [ "${V1567_PHYSICAL_CLEAN_PARTIAL:-0}" = 1 ]; then
    DAIMOS_TSFS_GATE_BREAK_BEFORE_CLEAN_V1567=$(awk \
        '$1 == "vfs_test_before_clean_v1567" {print $2}' "$build/kcore.map")
    DAIMOS_TSFS_GATE_BREAK_FAILED_CLEAN_V1567=$(awk \
        '$1 == "vfs_test_after_failed_clean_v1567" {print $2}' "$build/kcore.map")
    export DAIMOS_TSFS_GATE_BREAK_BEFORE_CLEAN_V1567
    export DAIMOS_TSFS_GATE_BREAK_FAILED_CLEAN_V1567
    case "$DAIMOS_TSFS_GATE_BREAK_BEFORE_CLEAN_V1567:$DAIMOS_TSFS_GATE_BREAK_FAILED_CLEAN_V1567" in
        ??????:??????) ;;
        *) echo 'FAIL v1567: no exact resident VFS breakpoint map addresses' >&2; exit 1 ;;
    esac
    echo "v1567: exact CLEAN breakpoints $DAIMOS_TSFS_GATE_BREAK_BEFORE_CLEAN_V1567 and $DAIMOS_TSFS_GATE_BREAK_FAILED_CLEAN_V1567"
fi

export DAIMOS_TSFS_PREBUILT_BUILD="$build"
export DAIMOS_TSFS_GATE_DTVOL2_V1564=1
if [ "${V1567_PHYSICAL_CLEAN_PARTIAL:-0}" = 1 ]; then
    # The fault only exists in an opt-in simulator with the diagnostic
    # Type-551 changed-word facility. The *production* driver and VFS
    # CLEAN/rollback leaf are unchanged in this disposable KCC image.
    export DAIMOS_TSFS_GATE_PARTIAL_CLEAN_V1567=1
    export DAIMOS_TSFS_GATE_EXPORT_PARTIAL_V1567="$work/physical-torn-clean-v1567.tap"
    export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-clean-partial-v1567.c"
    export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSCLEAN V1567'
    export DAIMOS_TSFS_GATE_STAGES_V1526='START RW_REFUSED MOUNTED DIRTY_ARMED READY_PARTIAL WRITE_FAILED POISONED PASS'
    echo 'v1567: real Type-551 DIRTY then interrupted physical CLEAN'
    sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
    test -s "$DAIMOS_TSFS_GATE_EXPORT_PARTIAL_V1567" || {
        echo 'FAIL v1567: no persistent physical torn CLEAN evidence' >&2
        exit 1
    }
    echo 'v1567: independent cold boot of actual physically torn RBN0'
    export DAIMOS_TSFS_PREBUILT_BUILD="$base"
    export DAIMOS_TSFS_GATE_V2_REPLAY_V1567="$DAIMOS_TSFS_GATE_EXPORT_PARTIAL_V1567"
    unset DAIMOS_TSFS_GATE_PARTIAL_CLEAN_V1567
    export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-v2-dirty-gate-v1564.c"
    export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSV2DIRTY V1564'
    export DAIMOS_TSFS_GATE_STAGES_V1526='START RW_REFUSED RO_REFUSED UNPUBLISHED PASS'
    sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
    echo 'PASS v1567: interrupted physical RBN0 CLEAN stays rejected after cold boot'
else
    export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-cross-owner-v1526.c"
    export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSV2 V1564'
    export DAIMOS_TSFS_GATE_STAGES_V1526='START RW_REFUSED MOUNTED CROSS_CWD_REFUSED CROSS_FILE_REFUSED CROSS_RETIRED REMOUNTED PASS'
    echo 'v1566: real Type-551 DIRTY arm -> CLEAN readback twice in PDP-6 guest'
    sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
    echo 'PASS v1566: physical DTVOL2 DIRTY->CLEAN under exclusive owner seal'
fi
