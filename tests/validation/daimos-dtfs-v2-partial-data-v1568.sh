#!/bin/sh
# Real Type-551 V2 DIRTY -> partially written DATA, then production cold boot.
# ALL V2 RW policy relaxation is confined to an isolated copied KCORE/MRES.
# Production v1555 RO guard, VFS, DTFS MRES and the physical driver are
# otherwise unchanged. The v1551/v1552/v1553/v1554 first-write gate is real.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mode=${V1568_MODE:-data}
case "$mode" in
    data|dir) ;;
    *) echo "v1568: invalid mode: $mode" >&2; exit 1 ;;
esac
work=$(mktemp -d "$TMPDIR/daimos-dtfs-v2-partial-data-v1568.XXXXXX")
if [ "${V1568_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1568: keeping physical fixture $work"
fi

base=${DAIMOS_V1568_BASE_BUILD:-}
if [ -z "$base" ]; then
    base="$work/production-build"
    echo 'v1568: building unmodified source-matched 256K KCC base image'
    PATH="$PDP10_PREFIX/bin:$PATH" make \
        -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$base" USERLAND_BUILD_ROOT="$base" \
        ROOT=tape BOOT=ptr PDP10_PREFIX="$PDP10_PREFIX" \
        PROC_BOOT_USERS=1 HOST_TOOLS="$PDP10_PREFIX/bin" \
        > "$work/base-build-v1568.log" 2>&1 || {
        tail -95 "$work/base-build-v1568.log" >&2
        exit 1
    }
fi
test -f "$base/kcore-asm/vfs.s" && \
    test -f "$base/kcore-asm/dtfs_runtime.s" && \
    test -f "$base/dtfs-mres.map" || {
    echo 'v1568: a complete source-matched production image is required' >&2
    exit 1
}
build="$work/guest-build"
mkdir -p "$build"
cp -a "$base/." "$build/"

python3 - "$DAIMOS_REPO" "$build" "$mode" <<'PY'
from pathlib import Path
import sys

repo, build = (Path(x) for x in sys.argv[1:3])
mode = sys.argv[3]
original_vfs = (repo / 'system/kernel/fs/vfs.s').read_text()
vfs_path = build / 'kcore-asm/vfs.s'
assert vfs_path.read_text() == original_vfs, 'stale or foreign VFS build'
# v1568 first attempt incorrectly changed VFS policy before the
# provider published the exact media word and saved 72-bit ID. The
# production mount sequence legitimately exposes an empty media word
# at that point; the correct test-only hook is inside the provider,
# AFTER both saved ID words are written. Keep all VFS code untouched.
if mode == 'dir':
    # Only this copied VFS gets two instruction breakpoints. The first
    # occurs immediately before the second DTFS CREATE, the second
    # directly after the original provider returns. No VFS syscall
    # or DTFS implementation is mocked. The counter is test-only BSS.
    anchor = ('vfs_create:\n'
              '        movei   5,6                    ; FS_MRES_OP_CREATE\n')
    assert original_vfs.count(anchor) == 1
    injection = (
        'vfs_create:\n'
        '        ldb     5,[POINT 6,1,5]\n'
        '        caie    5,5\n'
        '        jrst    vfs_test_dir_normal_v1568\n'
        '        aos     vfs_test_dir_count_v1568\n'
        '        move    5,vfs_test_dir_count_v1568\n'
        '        caie    5,2\n'
        '        jrst    vfs_test_dir_normal_v1568\n'
        '        .globl vfs_test_before_dir_create_v1568\n'
        'vfs_test_before_dir_create_v1568:\n'
        '        move    5,5             ; unique physical fault stop\n'
        'vfs_test_dir_normal_v1568:\n'
        '        movei   5,6                    ; FS_MRES_OP_CREATE\n')
    original_vfs = original_vfs.replace(anchor, injection, 1)
    after = ('vfs_create_store_result:\n'
             '        jumpn   1,vfs_create_done\n')
    assert original_vfs.count(after) == 1
    post = (
        'vfs_create_store_result:\n'
        '        move    5,vfs_test_dir_count_v1568\n'
        '        caie    5,2\n'
        '        jrst    vfs_test_dir_after_done_v1568\n'
        '        .globl vfs_test_after_dir_create_v1568\n'
        'vfs_test_after_dir_create_v1568:\n'
        '        move    5,5             ; post-failure hardware stop\n'
        'vfs_test_dir_after_done_v1568:\n'
        '        jumpn   1,vfs_create_done\n')
    original_vfs = original_vfs.replace(after, post, 1)
    original_vfs += ('\n        .bss\n'
                     '        .globl vfs_test_dir_count_v1568\n'
                     'vfs_test_dir_count_v1568: .block 1\n')
    vfs_path.write_text(original_vfs)

names = ('dtfs_runtime.s', 'dtfs_intent_validate_v1550.s',
         'dtfs_v2_mount_exclusive_v1557.s',
         'dtfs_intent_mount_gate_v1561.s',
         'dtfs_intent_first_write_v1553.s',
         'dtfs_intent_owned_arm_v1552.s',
         'dtfs_intent_arm_v1551.s',
         'dtfs_intent_verify_v1554.s',
         'dtfs_intent_clean_v1566.s',
         'dtfs_intent_mount_seal_v1566.s')
original_dtfs = ('.set DTFS_ENABLE_TENEX,0\n'
                 '.set DTFS_ENABLE_ITS,0\n'
                 '.set DTFS_ENABLE_FOREIGN,0\n' +
                 ''.join((repo / 'system/kernel/fs' / n).read_text()
                         for n in names))
dtfs_path = build / 'kcore-asm/dtfs_runtime.s'
assert dtfs_path.read_text() == original_dtfs, 'stale or foreign DTFS MRES'

publish = ('        move    1,-1(17)               ; low half\n'
           '        movem   1,(2)\n'
           '        setzm   dtfs_cache_mount\n')
assert original_dtfs.count(publish) == 1
late_policy = (
    '        move    1,-1(17)               ; low half\n'
    '        movem   1,(2)\n'
    '        ; v1568 DISPOSABLE: real DTC3 V2 ID published first.\n'
    '        move    5,010\n'
    '        trnn    5,0100000\n'
    '        jrst    dtfs_test_rw_publish_done_v1568\n'
    '        andi    5,7\n'
    '        caie    5,3\n'
    '        jrst    dtfs_test_rw_publish_done_v1568\n'
    '        caie    012,2               ; exact public mount2 only\n'
    '        jrst    dtfs_test_rw_publish_done_v1568\n'
    '        movei   5,2\n'
    '        andcam  5,vfs_mount_policy\n'
    '        .globl dtfs_test_rw_publish_done_v1568\n'
    'dtfs_test_rw_publish_done_v1568:\n'
    '        setzm   dtfs_cache_mount\n')
original_dtfs = original_dtfs.replace(publish, late_policy, 1)

# This test-only bypass is not compiled into production. It permits
# DTC3 writes only after the exact authenticated published V2 slot1
# has been temporarily marked writable. The original v1561 first-
# write gate remains in place and MUST still physically arm DIRTY.
anchor = 'dtfs_v2_ro_write_guard_v1555:\n'
assert original_dtfs.count(anchor) == 1
extra = (
    anchor+
    '        ; v1568 DISPOSABLE ONLY, exact DTC3 V2 slot1 test\n'
    '        caie    1,3\n'
    '        jrst    dtfs_test_guard_normal_v1568\n'
    '        move    5,vfs_mount_root_base\n'
    '        jumpe   5,dtfs_test_guard_normal_v1568\n'
    '        move    5,1(5)\n'
    '        ldb     6,[POINT 6,5,5]\n'
    '        caie    6,5\n'
    '        jrst    dtfs_test_guard_normal_v1568\n'
    '        ldb     6,[POINT 6,5,11]\n'
    '        caie    6,2\n'
    '        jrst    dtfs_test_guard_normal_v1568\n'
    '        move    5,dtfs_media_base\n'
    '        jumpe   5,dtfs_test_guard_normal_v1568\n'
    '        move    5,1(5)\n'
    '        trnn    5,0100000\n'
    '        jrst    dtfs_test_guard_normal_v1568\n'
    '        andi    5,7\n'
    '        caie    5,3\n'
    '        jrst    dtfs_test_guard_normal_v1568\n'
    '        move    5,vfs_mount_policy\n'
    '        trne    5,2               ; still readonly: do not bypass\n'
    '        jrst    dtfs_test_guard_normal_v1568\n'
    '        jrst    dtfs_v2_write_allowed_v1555\n'
    '        .globl dtfs_test_guard_normal_v1568\n'
    'dtfs_test_guard_normal_v1568:\n')
dtfs_path.write_text(original_dtfs.replace(anchor, extra, 1))
assert 'pushj   17,dtfs_intent_mount_gate_v1561' in original_dtfs
assert 'dtfs_intent_first_write_v1553:' in original_dtfs
assert 'dtfs_intent_owned_arm_v1552:' in original_dtfs
assert 'dtfs_intent_owned_verify_v1554:' in original_dtfs
print('PASS v1568: copied image only; v1551-v1554 native gate unchanged')
PY

echo 'v1568: assembling isolated VFS/MRES and complete boot image'
PATH="$PDP10_PREFIX/bin:$PATH" make \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" USERLAND_BUILD_ROOT="$build" \
    ROOT=tape BOOT=ptr PDP10_PREFIX="$PDP10_PREFIX" \
    PROC_BOOT_USERS=1 HOST_TOOLS="$PDP10_PREFIX/bin" \
    > "$work/guest-build-v1568.log" 2>&1 || {
    tail -95 "$work/guest-build-v1568.log" >&2
    exit 1
}
grep -q '^dtfs_test_rw_publish_done_v1568' "$build/dtfs-mres.map" || {
    echo 'FAIL v1568: late provider test policy boundary absent' >&2
    exit 1
}
grep -q '^dtfs_test_guard_normal_v1568' "$build/dtfs-mres.map" || {
    echo 'FAIL v1568: DTFS test boundary absent from linked image' >&2
    exit 1
}
if [ "$mode" = dir ]; then
    DAIMOS_TSFS_GATE_BREAK_BEFORE_DIR_V1568=$(awk \
        '$1 == "vfs_test_before_dir_create_v1568" {print $2}' "$build/kcore.map")
    DAIMOS_TSFS_GATE_BREAK_AFTER_DIR_V1568=$(awk \
        '$1 == "vfs_test_after_dir_create_v1568" {print $2}' "$build/kcore.map")
    export DAIMOS_TSFS_GATE_BREAK_BEFORE_DIR_V1568
    export DAIMOS_TSFS_GATE_BREAK_AFTER_DIR_V1568
    case "$DAIMOS_TSFS_GATE_BREAK_BEFORE_DIR_V1568:$DAIMOS_TSFS_GATE_BREAK_AFTER_DIR_V1568" in
        ??????:??????) ;;
        *) echo 'FAIL v1568: missing linked KCORE DIR breakpoints' >&2; exit 1 ;;
    esac
    echo "v1568: exact DIR VFS breakpoints: $DAIMOS_TSFS_GATE_BREAK_BEFORE_DIR_V1568 $DAIMOS_TSFS_GATE_BREAK_AFTER_DIR_V1568"
fi

# Use existing v1529 actual two-word RBN0145 partial-transfer guest,
# changing ONLY its initial mount policy request and adding proof that
# unmodified production RW admission was first refused. C is C89.
python3 - "$self" "$work" <<'PY'
from pathlib import Path
import sys
self, work = (Path(x) for x in sys.argv[1:])
source = (self / '../target/daimos-dtfs-partial-write-v1529.c').read_text()
anchor = ('    if (partial_step_v1529("START") != 0 ||\n'
          '        dsys_dtfs_mount(partial_device_v1529, partial_target_v1529,\n'
          '            SYS_DTFS_TYPE_NATIVE) != 0 ||\n')
assert source.count(anchor) == 1
replacement = (
    '    if (partial_step_v1529("START") != 0 ||\n'
    '        dsys_dtfs_mount(partial_device_v1529, partial_target_v1529,\n'
    '            SYS_DTFS_TYPE_NATIVE) == 0 ||\n'
    '        dsys_dtfs_mount(partial_device_v1529, partial_target_v1529,\n'
    '            SYS_DTFS_TYPE_NATIVE | SYS_MOUNT_RDONLY) != 0 ||\n')
source = source.replace(anchor, replacement, 1)
(work / 'guest-v1568.c').write_text(source)
print('PASS v1568: real guest checks v1555 RW admission refused first')
PY

export DAIMOS_TSFS_SIMH="${DAIMOS_TSFS_SIMH:-$PDP10_PREFIX/bin/pdp6-v1529r5}"
test -x "$DAIMOS_TSFS_SIMH" || {
    echo 'v1568: real Type-551 changed-word diagnostic simulator absent' >&2
    exit 1
}
export DAIMOS_TSFS_PREBUILT_BUILD="$build"
export DAIMOS_TSFS_GATE_DTVOL2_V1564=1
if [ "$mode" = dir ]; then
    export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-v2-partial-dir-v1568.c"
    export DAIMOS_TSFS_GATE_PARTIAL_V2_DIR_V1568=1
    export DAIMOS_TSFS_GATE_EXPORT_DIR_V1568="$work/real-v2-partial-dir-v1568.tap"
    export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSDIR V1568'
    export DAIMOS_TSFS_GATE_STAGES_V1526='START DIRTY_ARMED READY_ARM WRITE_FAILED READY_VERIFY STICKY_CONFIRMED PASS'
    replay="$DAIMOS_TSFS_GATE_EXPORT_DIR_V1568"
else
    export DAIMOS_TSFS_GATE_SOURCE_V1526="$work/guest-v1568.c"
    export DAIMOS_TSFS_GATE_PARTIAL_V1529=1
    export DAIMOS_TSFS_GATE_PARTIAL_V2_DATA_V1568=1
    export DAIMOS_TSFS_GATE_EXPORT_DATA_V1568="$work/real-v2-partial-data-v1568.tap"
    export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSPART V1529'
    export DAIMOS_TSFS_GATE_STAGES_V1526='START SEED_TRUNCATE_OK READY_ARM WRITE_FAILED READY_VERIFY STICKY_CONFIRMED PASS'
    replay="$DAIMOS_TSFS_GATE_EXPORT_DATA_V1568"
fi
echo "v1568: booting V2 and forcing one changed physical $mode word"
sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
test -s "$replay" || {
    echo 'FAIL v1568: missing physically torn V2 tape' >&2
    exit 1
}

# Cold boot the EXACT real torn DATA tape on the unchanged base KCORE.
export DAIMOS_TSFS_PREBUILT_BUILD="$base"
export DAIMOS_TSFS_GATE_V2_REPLAY_DIRTY_V1568="$replay"
unset DAIMOS_TSFS_GATE_PARTIAL_V1529
unset DAIMOS_TSFS_GATE_PARTIAL_V2_DATA_V1568
unset DAIMOS_TSFS_GATE_PARTIAL_V2_DIR_V1568
unset DAIMOS_TSFS_GATE_BREAK_BEFORE_DIR_V1568
unset DAIMOS_TSFS_GATE_BREAK_AFTER_DIR_V1568
export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-v2-dirty-gate-v1564.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSV2DIRTY V1564'
export DAIMOS_TSFS_GATE_STAGES_V1526='START RW_REFUSED RO_REFUSED UNPUBLISHED PASS'
echo 'v1568: cold boot same physically damaged DTVOL2/DIRTY tape'
sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
echo "PASS v1568: real V2 $mode partial write and subsequent production cold boot"
