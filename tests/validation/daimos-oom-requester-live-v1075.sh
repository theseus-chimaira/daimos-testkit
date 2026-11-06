#!/bin/sh
# Disposable PDP-6 full-system physical OOM test: kill ONLY the requester.
# Production OOM BRK remains default-off. No production source is edited.
# Set V1075_TEST_OOM_ENABLED=0 for the full-guest negative control.
set -eu
: "${PDP10_PREFIX:?}" "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
enable=${V1075_TEST_OOM_ENABLED:-1}
negatives=${V1110_TEST_NEGATIVES:-0}
bad_run=${V1112_TEST_FAILED_RUN:-0}
mm_slots=${V1114_TEST_MM_SLOTS:-0}
mm_fragment=${V1115_TEST_MM_FRAGMENT:-0}
run_cause=${V1116_TEST_RUN_CAUSE:-0}
pid_reuse=${V1120_TEST_PID_REUSE:-0}
held_provider=${V1150_TEST_HELD_PROVIDER:-0}
endurance=${V1151_TEST_ENDURANCE:-0}
disk_full=${V1156_TEST_DISK_FULL:-0}
combined=${V1158_TEST_COMBINED:-0}
protected=${V1159_TEST_PROTECTED:-0}
release_media=${V1160_RELEASE_MEDIA:-0}
residency=${V1174_TEST_RESIDENCY:-0}
f07_peak=${V1203_TEST_F07_PEAK:-0}
f07_high=${V1204_TEST_F07_HIGH:-0}
f07_concurrent=${V1205_TEST_CONCURRENT:-0}
f07_combined=${V1206_TEST_COMBINED:-0}
f07_swapslots=${V1207_TEST_SWAPSLOTS:-0}
batch_term=${V1262_TEST_BATCH_TERM:-0}
case "$enable" in
    0|1) ;;
    *) echo 'v1075: invalid V1075_TEST_OOM_ENABLED' >&2; exit 2 ;;
esac
case "$negatives" in
    0|1) ;;
    *) echo 'v1110: invalid negative-control mode' >&2; exit 2 ;;
esac
case "$bad_run" in
    0|1) ;;
    *) echo 'v1112: invalid failed-RUN mode' >&2; exit 2 ;;
esac
case "$mm_slots" in
    0|1) ;;
    *) echo 'v1114: invalid MM descriptor mode' >&2; exit 2 ;;
esac
case "$mm_fragment" in
    0|1) ;;
    *) echo 'v1115: invalid MM fragmentation mode' >&2; exit 2 ;;
esac
case "$run_cause" in
    0|1) ;;
    *) echo 'v1116: invalid RUN cause mode' >&2; exit 2 ;;
esac
case "$pid_reuse" in
    0|1) ;;
    *) echo 'v1120: invalid PID-reuse mode' >&2; exit 2 ;;
esac
case "$held_provider" in
    0|1) ;;
    *) echo 'v1150: invalid provider mode' >&2; exit 2 ;;
esac
case "$endurance" in
    0|1) ;;
    *) echo 'v1151: invalid endurance mode' >&2; exit 2 ;;
esac
case "$disk_full" in
    0|1) ;;
    *) echo 'v1156: invalid backing exhaustion mode' >&2; exit 2 ;;
esac
case "$combined" in
    0|1) ;;
    *) echo 'v1158: invalid combined mode' >&2; exit 2 ;;
esac
case "$protected" in
    0|1) ;;
    *) echo 'v1159: invalid protected mode' >&2; exit 2 ;;
esac
case "$release_media" in
    0|1) ;;
    *) echo 'v1160: invalid release-media mode' >&2; exit 2 ;;
esac
case "$residency" in
    0|1) ;;
    *) echo 'v1174: invalid residency-audit mode' >&2; exit 2 ;;
esac
case "$f07_peak" in
    0|1) ;;
    *) echo 'v1203: invalid F07 peak observation mode' >&2; exit 2 ;;
esac
case "$f07_high" in
    0|1) ;;
    *) echo 'v1204: invalid F07 high-pressure mode' >&2; exit 2 ;;
esac
if [ "$f07_high" = 1 ] && [ "$f07_peak" != 1 ]; then
    echo 'v1204: requires v1203 atomic MM snapshot' >&2
    exit 2
fi
case "$f07_concurrent" in
    0|1) ;;
    *) echo 'v1205: invalid F07 concurrent-process mode' >&2; exit 2 ;;
esac
case "$f07_combined" in
    0|1) ;;
    *) echo 'v1206: invalid combined F07 mode' >&2; exit 2 ;;
esac
case "$f07_swapslots" in
    0|1) ;;
    *) echo 'v1207: invalid swap-slot F07 mode' >&2; exit 2 ;;
esac
if [ "$f07_swapslots" = 1 ] && {
    [ "$f07_concurrent" != 1 ] || [ "$f07_peak" != 1 ] ||
    [ "$f07_combined" != 0 ] || [ "$f07_high" != 0 ]; }; then
    echo 'v1207: requires v1203/v1205 real processes without synthetic pressure' >&2
    exit 2
fi
if [ "$batch_term" != 0 ] && [ "$batch_term" != 1 ]; then
    echo 'v1262: invalid batch termination mode' >&2
    exit 2
fi
if [ "$batch_term" = 1 ] && [ "$f07_swapslots" != 1 ]; then
    echo 'v1262: batch termination requires swap-slot F07 mode' >&2
    exit 2
fi
if [ "$f07_concurrent" = 1 ] && {
    [ "$f07_peak" != 1 ] ||
    { [ "$f07_high" != 0 ] && [ "$f07_combined" != 1 ]; }; }; then
    echo 'v1205: requires v1203 snapshot, or v1206 small-only MM pressure' >&2
    exit 2
fi
if [ "$f07_combined" = 1 ] && {
    [ "$f07_peak" != 1 ] || [ "$f07_high" != 1 ] ||
    [ "$f07_concurrent" != 1 ]; }; then
    echo 'v1206: requires simultaneous v1203/v1204/v1205 fixtures' >&2
    exit 2
fi
if [ "$f07_peak" = 1 ] && {
    [ "$held_provider" != 1 ] || [ "$protected" != 1 ] ||
    [ "$release_media" != 1 ] || [ "$residency" != 0 ]; }; then
    echo 'v1203: require release-media protected physical OOM with held FS owner' >&2
    exit 2
fi
if [ "$residency" = 1 ] && [ "$release_media" != 1 ]; then
    echo 'v1174: require explicit release-media boot profile' >&2
    exit 2
fi
if [ "$release_media" = 1 ]; then
    if [ "$protected" != 1 ] || [ "$held_provider" != 1 ] ||
        [ -z "${V1160_EVIDENCE_DIR:-}" ]; then
        echo 'v1160: require held-provider E12 and evidence directory' >&2
        exit 2
    fi
fi
if [ "$protected" = 1 ] && { [ "$held_provider" != 1 ] ||
    [ "$combined" != 0 ] || [ "$endurance" != 0 ] ||
    [ "$disk_full" != 0 ] || [ "$mm_slots" != 0 ] ||
    [ "$mm_fragment" != 0 ] || [ "$run_cause" != 0 ] ||
    [ "$negatives" != 0 ] || [ "$bad_run" != 0 ] ||
    [ "$pid_reuse" != 0 ]; }; then
    echo 'v1159: requires isolated held-provider OOM guest' >&2
    exit 2
fi
if [ "$combined" = 1 ] && { [ "$mm_slots" != 1 ] ||
    [ "$run_cause" != 1 ] || [ "$bad_run" != 0 ] ||
    [ "$held_provider" != 0 ] || [ "$endurance" != 0 ] ||
    [ "$disk_full" != 0 ] || [ "$mm_fragment" != 0 ] ||
    [ "$pid_reuse" != 0 ]; }; then
    echo 'v1158: combined mode requires actual RUN MM failure' >&2
    exit 2
fi
if [ "$disk_full" = 1 ] && { [ "$held_provider" != 0 ] ||
    [ "$endurance" != 0 ] || [ "$mm_slots" != 0 ] ||
    [ "$mm_fragment" != 0 ] || [ "$run_cause" != 0 ] ||
    [ "$negatives" != 0 ] || [ "$bad_run" != 0 ] ||
    [ "$pid_reuse" != 0 ]; }; then
    echo 'v1156: independent backing-full guest required' >&2
    exit 2
fi
if [ "$endurance" = 1 ] && { [ "$pid_reuse" != 1 ] ||
    [ "$held_provider" != 0 ] || [ "$negatives" != 0 ] ||
    [ "$bad_run" != 0 ] || [ "$mm_slots" != 0 ] ||
    [ "$mm_fragment" != 0 ] || [ "$run_cause" != 0 ]; }; then
    echo 'v1151: endurance needs PID reuse without other fault modes' >&2
    exit 2
fi
if [ "$held_provider" = 1 ] && { [ "$negatives" != 0 ] ||
    [ "$bad_run" != 0 ] || [ "$mm_slots" != 0 ] ||
    [ "$mm_fragment" != 0 ] || [ "$run_cause" != 0 ] ||
    [ "$pid_reuse" != 0 ]; }; then
    echo 'v1150: provider guest has a separate fault matrix' >&2
    exit 2
fi
if [ "$run_cause" = 1 ] && [ "$mm_slots" != 1 ]; then
    echo 'v1116: RUN cause requires MM descriptor pressure' >&2
    exit 2
fi
if [ "$mm_slots" = 1 ] && [ "$mm_fragment" = 1 ]; then
    echo 'v1115: only one MM fault mode per disposable kernel' >&2
    exit 2
fi
work=$(mktemp -d "$TMPDIR/daimos-oom-requester-live-v1075.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1075 work: $work"; fi' EXIT HUP INT TERM
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 - "$work/source/system/kernel/proc/syscall_dispatch_pdp6.s" "$enable" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
original = '.equ    PROC_OOM_BRK_ENABLED_V1000,0'
assert s.count(original) == 1, 'OOM option changed; audit before enabling test'
if sys.argv[2] == '1':
    p.write_text(s.replace(original,
                           '.equ    PROC_OOM_BRK_ENABLED_V1000,1', 1))
PY
if [ "$held_provider" = 1 ]; then
    python3 "$self/daimos-oom-provider-held-v1150.py" \
        "$work/source/system/kernel" "$enable"
fi
if [ "$protected" = 1 ]; then
    python3 "$self/daimos-oom-protected-v1159.py" \
        "$work/source/system/kernel" "$f07_swapslots"
fi
if [ "$f07_peak" = 1 ]; then
    python3 "$self/daimos-f07-mm-peak-v1203.py" \
        "$work/source/system/kernel"
fi
if [ "$f07_high" = 1 ]; then
    if [ "$f07_combined" = 1 ]; then
        python3 "$self/daimos-f07-mm-high-v1204.py" \
            "$work/source/system/kernel" small-only-v1206
    else
        python3 "$self/daimos-f07-mm-high-v1204.py" \
            "$work/source/system/kernel"
    fi
fi
if [ "$f07_concurrent" = 1 ]; then
    python3 "$self/daimos-f07-real-proc-v1205.py" \
        "$work/source/system/kernel"
fi
if [ "$f07_swapslots" = 1 ]; then
    if [ "${V1225_IDLE_STACK_EXPERIMENT:-0}" = 1 ]; then
        python3 "$self/daimos-f07-idle-stack-v1225.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1228_RUN_CAUSE_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-run-cause-v1228.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1229_EXEC_STAGE_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-exec-stage-v1229.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1230_EXEC_READ_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-exec-read-v1230.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1231_D6FS_READ_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-d6fs-read-v1231.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1232_FCB_GATE_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-fcb-gate-v1232.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1233_FCB_TYPE_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-fcb-type-v1233.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1234_CACHE_FCB_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-cache-fcb-v1234.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1235_CACHE_AT_FCB_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-cache-at-fcb-v1235.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1236_SWAP_WORKSPACE_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-swap-workspace-v1236.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1232_D6FS_FCB_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-d6fs-fcb-v1232.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1233_D6FS_BACKING_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-d6fs-backing-compare-v1233.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1234_BCACHE_HIT_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-bcache-hit-v1234.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1235_FCB_FREEZE_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-fcb-hit-freeze-v1235.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1236_D6FS_FETCH_STAGES_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-d6fs-fetch-stages-v1236.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1253_DISPATCH_TALLY_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-dispatch-tally-v1253.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1238_SCHEDULER_SNAPSHOT_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-scheduler-snapshot-v1238.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1250_SLOT0_WAIT_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-slot0-wait-v1250.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1240_SWAP_RECORD_PROBE:-0}" = 1 ]; then
        if [ "${V1238_SCHEDULER_SNAPSHOT_PROBE:-0}" != 1 ]; then
            echo 'v1240: requires v1238 scheduler snapshot' >&2
            exit 2
        fi
        python3 "$self/daimos-f07-swap-record-v1240.py" \
            "$work/source/system/kernel"
    fi
    python3 "$self/daimos-f07-swapstack-v1207.py" \
        "$work/source/system/kernel"
    if [ "${V1214_INVALID_UUO_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-invalid-uuo-v1214.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1242_INVALID_OWNER_PROBE:-0}" = 1 ]; then
        if [ "${V1214_INVALID_UUO_PROBE:-0}" != 1 ]; then
            echo 'v1242: requires v1214 first invalid-UUO halt' >&2
            exit 2
        fi
        python3 "$self/daimos-f07-invalid-owner-v1242.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1212_FINALIZER_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-finalizer-probe-v1212.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1217_OWNER_BRANCH_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-owner-branch-v1217.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1218_SWAP_META_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-swap-meta-v1218.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1219_SWAP_ALLOCATOR_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-swap-allocator-v1219.py" \
            "$work/source/system/kernel"
    fi
    if [ "${V1220_UAREA_LIFETIME_PROBE:-0}" = 1 ]; then
        python3 "$self/daimos-f07-uarea-lifetime-v1220.py" \
            "$work/source/system/kernel"
    fi
fi
if [ "$endurance" = 1 ]; then
    python3 "$self/daimos-oom-endurance-v1151.py" \
        "$work/source/system/kernel"
fi
if [ "$disk_full" = 1 ]; then
    python3 "$self/daimos-oom-disk-full-v1156.py" \
        "$work/source/system/kernel"
fi
if [ "$mm_slots" = 1 ]; then
    python3 - "$work/source/system/kernel/proc/syscall_dispatch_pdp6.s" \
        "$self/daimos-oom-mm-slots-v1114.s" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
snippet = Path(sys.argv[2]).read_text()
before, after = snippet.split('; Definitions appended after the original syscall assembly file.', 1)
source = p.read_text()
anchor = 'native_sys_brk:\n'
assert source.count(anchor) == 1, 'v1114: syscall entry changed'
p.write_text(source.replace(anchor, anchor + before, 1) + '\n' + after)
PY
fi
if [ "$run_cause" = 1 ]; then
    python3 - "$work/source/system/kernel/proc/vm_pdp6.s" \
        "$work/source/system/kernel/proc/proc_run.s" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
run = Path(sys.argv[2])
s = p.read_text()
anchor = ('        pushj   17,mm_alloc_aligned\n'
          '        sub     17,kconst_2_2\n'
          '        jumpn   1,vm_space_create_fail\n')
assert s.count(anchor) == 1, 'v1116: VM create allocator contract changed'
header = '        .globl  vm_space_create\n'
assert s.count(header) == 1
s = s.replace(header, header + '        .globl  v1116_last_vm_cause\n', 1)
s = s.replace(anchor, anchor.replace('        jumpn',
            '        movem   1,v1116_last_vm_cause\n        jumpn'), 1)
p.write_text(s)

# RUN allocates the child u-area only after successful VM construction.
# Capture that later production MM result before it becomes generic -1.
s = run.read_text()
header = '        .globl  mm_alloc_aligned\n'
anchor = ('        pushj   17,mm_alloc_aligned\n'
          '        move    014,-2(17)\n'
          '        sub     17,kconst_3_3\n'
          '        jumpn   1,proc_run_mm_bad\n')
assert s.count(header) == 1 and s.count(anchor) == 1
s = s.replace(header, header + '        .globl  v1116_last_run_cause\n', 1)
s = s.replace(anchor, anchor.replace('        jumpn',
            '        movem   1,v1116_last_run_cause\n        jumpn'), 1)
run.write_text(s)
PY
fi
if [ "$mm_fragment" = 1 ]; then
    python3 - "$work/source/system/kernel/proc/syscall_dispatch_pdp6.s" \
        "$work/source/system/kernel/mm/mm_pdp6.s" \
        "$self/daimos-oom-mm-fragment-v1115.s" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
mm = Path(sys.argv[2])
snippet = Path(sys.argv[3]).read_text()
before, after = snippet.split(
    '; Immediately after the production VM BRK call, before policy checking:', 1)
note, definitions = after.split(
    '; Definitions appended after the original syscall assembly file.', 1)
assert 'movem   2,v1115_last_cause' in note
source = p.read_text()
entry = 'native_sys_brk:\n'
call = '        pushj   17,vm_space_brk_current\n'
assert source.count(entry) == 1 and source.count(call) == 1
source = source.replace(entry, entry + before, 1)
source = source.replace(call, call +
                        '        movem   2,v1115_last_cause\n', 1)
p.write_text(source + '\n' + definitions)
# mm_find_fit is deliberately private in production. Export it only
# in this disposable test copy to observe genuine fragmented gaps.
mm_source = mm.read_text()
mm_anchor = '        .globl  mm_alloc_aligned_noreclaim\n'
assert mm_source.count(mm_anchor) == 1
mm.write_text(mm_source.replace(mm_anchor,
                               mm_anchor + '        .globl  mm_find_fit\n', 1))
PY
fi

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
"$das" -F -C -O "$work/user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$work/user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
incs=
for sub in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$sub"
done
# v1259: optional disposable user-side BRK entry/exit trace. A copied
# fixture keeps diagnostics out of the original test source and kernel.
requester_source="$self/daimos-oom-requester-live-v1075.c"
if [ "${V1259_REQUESTER_STAGE_TRACE:-0}" = 1 ]; then
    if [ "${V1207_TEST_SWAPSLOTS:-0}" != 1 ]; then
        echo 'v1259: requires V1207_TEST_SWAPSLOTS=1' >&2
        exit 2
    fi
    cp "$self/../test_sixbit.h" "$work/test_sixbit.h"
    python3 "$self/daimos-f07-requester-stage-v1259.py" \
        "$requester_source" "$work/user/init-v1259.c"
    requester_source="$work/user/init-v1259.c"
fi
# shellcheck disable=SC2086
"$cc" -std=c89 -Os -DV1075_TEST_OOM_ENABLED="$enable" \
    -DV1110_TEST_NEGATIVES="$negatives" \
    -DV1112_TEST_FAILED_RUN="$bad_run" \
    -DV1114_TEST_MM_SLOTS="$mm_slots" \
    -DV1115_TEST_MM_FRAGMENT="$mm_fragment" \
    -DV1116_TEST_RUN_CAUSE="$run_cause" \
    -DV1120_TEST_PID_REUSE="$pid_reuse" \
    -DV1150_TEST_HELD_PROVIDER="$held_provider" \
    -DV1151_TEST_ENDURANCE="$endurance" \
    -DV1156_TEST_DISK_FULL="$disk_full" \
    -DV1158_TEST_COMBINED="$combined" \
    -DV1159_TEST_PROTECTED="$protected" \
    -DV1174_TEST_RESIDENCY="$residency" \
    -DV1204_TEST_F07_HIGH="$f07_high" \
    -DV1205_TEST_CONCURRENT="$f07_concurrent" \
    -DV1207_TEST_SWAPSLOTS="$f07_swapslots" \
    -DV1262_TEST_BATCH_TERM="$batch_term" \
    $incs -I"$DAIMOS_REPO/userland/libc" \
    -S "$requester_source" -o "$work/user/init.s"
"$das" -F -C -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$("$cc" -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"
grep -Eq '^_start[[:space:]]+000020$' "$work/user/init.map"

build="$work/build/system/boot/pdp6"
port=$((30000 + ($$ % 10000)))
printf 'v1075: building disposable PDP-6 physical-OOM guest (enabled=%s)\n' "$enable"
# E13 release candidate: explicitly select the disk boot path rather than
# inheriting ROOT=auto from the development build. Other tests keep their
# original source/target configurations.
set --
if [ "$release_media" = 1 ]; then
    set -- BOOT=dsk ROOT=disk ROOTSET=1 COMPILER=kcc \
        WALL_CLOCK_HZ=60 SIMH_PCLK_MODE=REALTIME
fi
PATH="$PDP10_PREFIX/bin:$PATH" "${MAKE:-make}" \
    -C "$DAIMOS_REPO/system/boot/pdp6" image "$@" \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" \
    KERNEL_DIR="$work/source/system/kernel" PROC_BOOT_USERS=1 \
    BOOT_PROFILE=full BOOT_CORE_WORDS=01000000 SIMH_CPU_KWORDS=256 \
    SIMH_DCS0_PORT="$port" SIMH_GE0_PORT="$((port + 10000))" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" SIMH_DPY_MODE=HEADLESS \
    PROC_STACK_WATERMARK="$f07_swapslots" \
    > "$work/build.log" 2>&1 || {
        tail -90 "$work/build.log" >&2
        exit 1
    }
sed -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' "$build/boot.ini" \
    > "$build/boot.v1075.tmp"
mv "$build/boot.v1075.tmp" "$build/boot.ini"

if [ "$held_provider" = 1 ]; then
    : > "$work/addresses"
    for name in armed holder_enter holder_lease holder_return release \
                predispatch fatal_busy ordinary_wait spinner real_oom \
                lease_at_oom error; do
        sym="daimos_test_${name}_v1150"
        addr=$(awk -v sym="$sym" '$1 == sym {print $2}' "$build/kcore.map")
        test -n "$addr" || { echo "v1150: missing $sym" >&2; exit 1; }
        printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
    done
    if [ "$protected" = 1 ]; then
        for name in requester init witness waiter spinner holder \
                    error snapshots selected select_calls; do
            sym="daimos_e12_${name}_v1159"
            addr=$(awk -v sym="$sym" '$1 == sym {print $2}' "$build/kcore.map")
            test -n "$addr" || { echo "v1159: missing $sym" >&2; exit 1; }
            printf 'e12_%s %s\n' "$name" "$addr" >> "$work/addresses"
        done
    fi
    if [ "$residency" = 1 ]; then
        for name in sys_resident_words_immediate mm_extent_capacity; do
            addr=$(awk -v sym="$name" '$1 == sym {print $2}' "$build/kcore.map")
            test -n "$addr" || { echo "v1174: missing $name" >&2; exit 1; }
            printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
        done
    fi
    if [ "$f07_peak" = 1 ]; then
        python3 - "$build/kcore.map" "$work/addresses" <<'PY'
from pathlib import Path
import sys

symbols = dict(line.split()[:2] for line in Path(sys.argv[1]).read_text().splitlines()
               if len(line.split()) >= 2)
names = ('samples', 'count', 'capacity', 'core', 'arena_count',
         'arena0', 'arena1', 'arena2', 'lease', 'buffer_base',
         'words', 'error')
with Path(sys.argv[2]).open('a') as out:
    for name in names:
        sym = 'daimos_f07_%s_v1203' % name
        assert sym in symbols, 'v1203 missing symbol ' + sym
        out.write('f07_%s %s\n' % (name, symbols[sym]))
    sym = 'daimos_f07_extents_v1203'
    assert sym in symbols, 'v1203 missing fixed snapshot table'
    base = int(symbols[sym], 8)
    for i in range(2 * 136):
        out.write('f07_extent%d %06o\n' % (i, base + i))
PY
    fi
    if [ "$f07_high" = 1 ]; then
        for name in count prepared freed error; do
            sym="daimos_f07_${name}_v1204"
            addr=$(awk -v sym="$sym" '$1 == sym {print $2}' "$build/kcore.map")
            test -n "$addr" || { echo "v1204: missing $sym" >&2; exit 1; }
            printf 'f07h_%s %s\n' "$name" "$addr" >> "$work/addresses"
        done
    fi
    if [ "$f07_concurrent" = 1 ]; then
        python3 - "$build/kcore.map" "$work/addresses" <<'PY'
from pathlib import Path
import sys

mapping = dict(line.split()[:2] for line in Path(sys.argv[1]).read_text().splitlines()
               if len(line.split()) >= 2)
with Path(sys.argv[2]).open('a') as out:
    for name in ('samples', 'slots', 'error'):
        sym = 'daimos_f07p_%s_v1205' % name
        assert sym in mapping, 'v1205 missing ' + sym
        out.write('f07p_%s %s\n' % (name, mapping[sym]))
    for name in ('meta', 'vm', 'sched', 'brk'):
        sym = 'daimos_f07p_%s_v1205' % name
        assert sym in mapping, 'v1205 missing ' + sym
        base = int(mapping[sym], 8)
        for i in range(64):
            out.write('f07p_%s%d %06o\n' % (name, i, base + i))
PY
    fi
    if [ "$f07_swapslots" = 1 ]; then
        python3 - "$build/kcore.map" "$work/addresses" <<'PY'
from pathlib import Path
import sys
mapping = dict(row.split()[:2] for row in Path(sys.argv[1]).read_text().splitlines()
               if len(row.split()) >= 2)
with Path(sys.argv[2]).open('a') as out:
    for label, sym in (
            ('swap_blocks', 'daimos_f07s_swap_blocks_v1207'),
            ('slot_capacity', 'daimos_f07s_slot_capacity_v1207'),
            ('swap_active', 'daimos_f07s_swap_active_v1207'),
            ('samples', 'daimos_f07s_samples_v1207'),
            ('error', 'daimos_f07s_error_v1207'),
            ('stack_peak', 'daimos_f07s_stack_peak_v1207'),
            ('idle_peak', 'daimos_f07s_idle_peak_v1207'),
            ('final_swap_blocks', 'proc_swap_blocks_used'),
            ('final_backstore_used', 'backstore_blocks_used'),
            ('final_swap_active', 'backstore_enabled'),
            ('final_process_high_slot', 'proc_high_slot'),
            ('final_process_current_slot', 'proc_current_slot'),
            ('final_mm_extent_count', 'mm_extent_count')):
        assert sym in mapping, 'v1207 missing ' + sym
        out.write('f07s_%s %s\n' % (label, mapping[sym]))
    # Diagnostic-only state: observe the actual scheduler state when a
    # slow or deadlocked guest is interrupted; never infer a PASS from it.
    for label, sym in (
            ('diag_sched_cursor', 'proc_sched_cursor'),
            ('diag_swap_backoff', 'proc_swap_pressure_ticks'),
            ('diag_runq_head', 'proc_runq_head'),
            ('diag_timer_clock', 'proc_timer_clock'),
            ('diag_timer_next', 'proc_timer_next'),
            ('diag_sched_kick', 'proc_sched_kick'),
            ('diag_last_reap_tick', 'proc_finish_last_tick_v881')):
        if sym in mapping:
            out.write('f07s_%s %s\n' % (label, mapping[sym]))
    if __import__('os').environ.get('V1214_INVALID_UUO_PROBE') == '1':
        for label, sym in (
                ('diag_invalid_word', 'mach_invalid_uuo_word'),
                ('diag_invalid_pc', 'mach_invalid_uuo_pc'),
                ('diag_file_table', 'file_table'),
                ('diag_owner_ptr', 'proc_current_ptr'),
                ('diag_owner_table', 'proc_table'),
                ('diag_kernel_sp', 'mach_kernel_sp'),
                ('diag_user_sp', 'mach_user_sp')):
            assert sym in mapping, 'v1214 missing native UUO diagnostic ' + sym
            out.write('f07s_%s %s\n' % (label, mapping[sym]))
    if __import__('os').environ.get('V1242_INVALID_OWNER_PROBE') == '1':
        for name in ('faults', 'slot', 'process_ptr', 'meta', 'vm', 'sched',
                     'uarea', 'ctx_pc', 'ctx_ksp', 'fdctl', 'saved_backing',
                     'swap_record', 'syscall_save', 'user_sp', 'kernel_sp',
                     'private_peak', 'idle_peak'):
            sym = 'daimos_f07i_%s_v1242' % name
            assert sym in mapping, 'v1242 missing invalid-UUO sample ' + sym
            out.write('f07i_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1217_OWNER_BRANCH_PROBE') == '1':
        for name in ('slot', 'files', 'ptr', 'meta', 'vm', 'sched',
                     'no_slot', 'no_file'):
            sym = 'daimos_f07o_%s_v1217' % name
            assert sym in mapping, 'v1217 missing native owner diagnostic ' + sym
            out.write('f07o_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1218_SWAP_META_PROBE') == '1':
        for name in ('out_calls', 'out_slot', 'out_before', 'out_after',
                     'out_result', 'in_calls', 'in_slot', 'in_before',
                     'in_after', 'in_result'):
            sym = 'daimos_f07m_%s_v1218' % name
            assert sym in mapping, 'v1218 missing swap transaction sample ' + sym
            out.write('f07m_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1219_SWAP_ALLOCATOR_PROBE') == '1':
        for name in ('calls', 'error', 'owner', 'requested', 'extents',
                     'low_fit', 'low_base_or_free', 'high_fit',
                     'high_base_or_free', 'meta'):
            sym = 'daimos_f07a_%s_v1219' % name
            assert sym in mapping, 'v1219 missing MM error snapshot ' + sym
            out.write('f07a_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1220_UAREA_LIFETIME_PROBE') == '1':
        for name in ('calls', 'pid1_calls', 'owner', 'before', 'after',
                     'sched', 'current', 'released'):
            sym = 'daimos_f07u_%s_v1220' % name
            assert sym in mapping, 'v1220 missing u-area lifetime ' + sym
            out.write('f07u_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1228_RUN_CAUSE_PROBE') == '1':
        for name in ('stage', 'result', 'slot', 'count'):
            sym = 'daimos_f07r_%s_v1228' % name
            assert sym in mapping, 'v1228 missing RUN admission ' + sym
            out.write('f07r_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1229_EXEC_STAGE_PROBE') == '1':
        for name in ('phase', 'calls'):
            sym = 'daimos_f07e_%s_v1229' % name
            assert sym in mapping, 'v1229 missing EXEC stage ' + sym
            out.write('f07e_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1230_EXEC_READ_PROBE') == '1':
        for name in ('calls', 'vnode', 'offset', 'destination',
                     'requested', 'returned'):
            sym = 'daimos_f07v_%s_v1230' % name
            assert sym in mapping, 'v1230 missing VFS payload read ' + sym
            out.write('f07v_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1231_D6FS_READ_PROBE') == '1':
        for name in ('provider_calls', 'requested', 'vnode',
                     'provider_bad_fcb', 'reader_fail', 'block_io_fail',
                     'position', 'done', 'target', 'provider_result'):
            sym = 'daimos_f07d_%s_v1231' % name
            assert sym in mapping, 'v1231 missing D6FS read sample ' + sym
            out.write('f07d_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1232_FCB_GATE_PROBE') == '1':
        for name in ('reason', 'index', 'limit', 'block', 'block_fail',
                     'decode_fail', 'type_fail', 'fcb_calls'):
            sym = 'daimos_f07c_%s_v1232' % name
            assert sym in mapping, 'v1232 missing FCB gate ' + sym
            out.write('f07c_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1233_FCB_TYPE_PROBE') == '1':
        for name in ('raw_meta', 'decoded_type', 'decoded_flags',
                     'decoded_size', 'fcb_copy', 'reader', 'type_samples'):
            sym = 'daimos_f07t_%s_v1233' % name
            assert sym in mapping, 'v1233 missing FCB type ' + sym
            out.write('f07t_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1234_CACHE_FCB_PROBE') == '1':
        for name in ('last_key', 'cache_path', 'fcb_source_meta',
                     'workspace_meta', 'fcb_index', 'fcb_block'):
            sym = 'daimos_f07b_%s_v1234' % name
            assert sym in mapping, 'v1234 missing FCB cache ' + sym
            out.write('f07b_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1235_CACHE_AT_FCB_PROBE') == '1':
        for name in ('fcb_key', 'fcb_cache_path', 'fcb_workspace_tag'):
            sym = 'daimos_f07h_%s_v1235' % name
            assert sym in mapping, 'v1235 missing cache-at-FCB ' + sym
            out.write('f07h_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1236_SWAP_WORKSPACE_PROBE') == '1':
        for name in ('scratch_calls', 'read_before', 'read_after',
                     'read_block', 'read_status', 'read_meta',
                     'fcb_before', 'fcb_after', 'fcb_block',
                     'fcb_status', 'fcb_meta'):
            sym = 'daimos_f07w_%s_v1236' % name
            assert sym in mapping, 'v1236 missing shared workspace ' + sym
            out.write('f07w_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1232_D6FS_FCB_PROBE') == '1':
        for name in ('reader_calls', 'reader_index', 'reader_limit',
                     'reader_base', 'index_reject', 'block_reject',
                     'decode_reject', 'type_reject', 'last_type',
                     'fcb_calls'):
            sym = 'daimos_f07c_%s_v1232' % name
            assert sym in mapping, 'v1232 missing FCB sample ' + sym
            out.write('f07c_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1233_D6FS_BACKING_PROBE') == '1':
        for name in ('rejects', 'index', 'block', 'cached_meta',
                     'disk_meta', 'backing_status', 'decoded_type'):
            sym = 'daimos_f07b_%s_v1233' % name
            assert sym in mapping, 'v1233 missing backing comparison ' + sym
            out.write('f07b_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1234_BCACHE_HIT_PROBE') == '1':
        for name in ('calls', 'key', 'mode', 'raw_word'):
            sym = 'daimos_f07k_%s_v1234' % name
            assert sym in mapping, 'v1234 missing cache observation ' + sym
            out.write('f07k_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1235_FCB_FREEZE_PROBE') == '1':
        for name in ('hits', 'key', 'mode', 'raw_word'):
            sym = 'daimos_f07h_%s_v1235' % name
            assert sym in mapping, 'v1235 missing frozen FCB observation ' + sym
            out.write('f07h_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1236_D6FS_FETCH_STAGES_PROBE') == '1':
        for name in ('reads', 'status', 'before_read', 'after_read',
                     'after_store', 'zero_after_read'):
            sym = 'daimos_f07x_%s_v1236' % name
            assert sym in mapping, 'v1236 missing D6FS fetch stage ' + sym
            out.write('f07x_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1238_SCHEDULER_SNAPSHOT_PROBE') == '1':
        for name in ('services', 'swap_request', 'selector_swap',
                     'selector_ready', 'selector_resident', 'selector_none',
                     'idle', 'timer', 'cursor', 'current', 'runq', 'high_slot',
                     'process_table', 'rt_owner', 'pid1_meta', 'pid1_vm',
                     'pid1_sched'):
            sym = 'daimos_f07q_%s_v1238' % name
            assert sym in mapping, 'v1238 missing scheduling probe ' + sym
            out.write('f07q_%s %s\n' % (name, mapping[sym]))
        sym = 'daimos_f07q_slots_v1238'
        assert sym in mapping, 'v1238 missing descriptor snapshot'
        base = int(mapping[sym], 8)
        for i in range(0o140):
            out.write('f07q_slot%03o %06o\n' % (i, base + i))
    if __import__('os').environ.get('V1250_SLOT0_WAIT_PROBE') == '1':
        for name in ('calls', 'event', 'event_value', 'sp', 'caller',
                     'drm_active', 'drm_pending', 'storage_state',
                     'storage_iowd', 'sched_cursor', 'current_slot',
                     'timer_clock', 'swap_backoff', 'pi_state', 'saved_ac0'):
            sym = 'daimos_f07w_%s_v1250' % name
            assert sym in mapping, 'v1250 missing slot-0 wait probe ' + sym
            out.write('f07wait_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1253_DISPATCH_TALLY_PROBE') == '1':
        sym = 'daimos_f07u_idle_count_v1253'
        assert sym in mapping, 'v1253 missing idle counter'
        out.write('f07u_idle %s\n' % mapping[sym])
        for name in ('dispatch', 'swapreq'):
            sym = 'daimos_f07u_%s_v1253' % name
            assert sym in mapping, 'v1253 missing bounded slot array ' + sym
            base = int(mapping[sym], 8)
            for slot in range(64):
                out.write('f07u_%s%02o %06o\n' % (name, slot, base + slot))
    if __import__('os').environ.get('V1240_SWAP_RECORD_PROBE') == '1':
        for name in ('record_base', 'pid1_record', 'pid5_record',
                     'pid1_backing', 'pid5_backing', 'reject_state',
                     'reject_vm', 'reject_record', 'reject_transition',
                     'pop_clear'):
            sym = 'daimos_f07z_%s_v1240' % name
            assert sym in mapping, 'v1240 missing swap record probe ' + sym
            out.write('f07z_%s %s\n' % (name, mapping[sym]))
    for name in ('pressure', 'fallback', 'victim_search',
                 'reclaim_ok', 'reclaim_fail', 'swapout_ok',
                 'swapout_fail', 'swapin_ok', 'swapin_pressure',
                 'swapin_fail', 'cooldown', 'exchanged', 'restored'):
        sym = 'daimos_f07s_%s_v1209' % name
        assert sym in mapping, 'v1209 missing diagnostic counter ' + sym
        out.write('f07s_diag_%s %s\n' % (name, mapping[sym]))
    if __import__('os').environ.get('V1212_FINALIZER_PROBE') == '1':
        for name in ('exit_calls', 'exit_slot', 'exit_ptr', 'exit_meta',
                     'written_uarea', 'written_marker', 'finish_owner',
                     'prevm_fail', 'vm_done', 'uarea_defer', 'hup_fail',
                     'finish_fail', 'exit_fail', 'fatal_no_owner',
                     'bad_slot', 'bad_status', 'bad_descriptor',
                     'bad_meta', 'bad_marker', 'fatal_slot',
                     'fatal_ptr', 'fatal_files'):
            sym = 'daimos_f07f_%s_v1212' % name
            assert sym in mapping, 'v1212 missing diagnostic ' + sym
            out.write('f07f_%s %s\n' % (name, mapping[sym]))
PY
    fi
    sed -i '/^exit$/d' "$build/boot.ini"
    while read -r name addr; do
        printf 'examine %s\n' "$addr" >> "$build/boot.ini"
    done < "$work/addresses"
    printf 'exit\n' >> "$build/boot.ini"
fi

if [ "${V1226_SIMH_HISTORY:-0}" = 1 ]; then
    # Debug-only hardware instruction ring. Capture the direct caller of
    # proc_swap_storage_invariant_v30 without modifying any guest state.
    python3 - "$build/boot.ini" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text()
assert text.count('go 020\n') == 1
text = text.replace('go 020\n',
                    'set cpu history=256\ngo 020\nshow cpu history=80\n', 1)
p.write_text(text)
PY
fi

if [ "${V1209_BUILD_ONLY:-0}" = 1 ]; then
    # Explicit diagnostic mode: keep this separately built disposable
    # complete guest for interactive SIMH state capture. This never
    # claims a PASS, and production source/boot images stay untouched.
    echo "v1209: diagnostic-only built guest: $work"
    exit 0
fi
printf 'v1075: booting patched disposable guest; production unchanged\n'
guest_timeout=90s
if [ "$endurance" = 1 ]; then guest_timeout=360s; fi
if [ "$f07_swapslots" = 1 ]; then guest_timeout=900s; fi
set +e
(cd "$build" && TERM=dumb SDL_VIDEODRIVER=dummy \
    SDL_AUDIODRIVER=dummy timeout -k 2s "$guest_timeout" stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) > "$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    if [ "$f07_swapslots" = 1 ]; then
        echo "v1207: milestone stream (diagnostic only): $(sed -n '/^</p' "$work/simh.out" | tr -cd '+~^@%*?{}|')" >&2
    fi
    tail -65 "$work/simh.out" >&2
    echo "v1075: SIMH exit $rc" >&2
    exit 1
fi
text=$(tr -d '\r\n' < "$work/simh.out")
if [ "${V1259_REQUESTER_STAGE_TRACE:-0}" = 1 ]; then
    case "$text" in
        *'&='*)
            if [ "$enable" != 0 ]; then
                echo 'v1259: enabled OOM BRK unexpectedly returned' >&2
                exit 1
            fi ;;
        *'&'*)
            if [ "$enable" != 1 ]; then
                echo 'v1259: disabled OOM BRK never returned' >&2
                exit 1
            fi ;;
        *) echo 'v1259: requester never entered BRK' >&2; exit 1 ;;
    esac
    text=$(printf '%s' "$text" | tr -d '&=')
fi
if [ "$f07_swapslots" = 1 ]; then
    # Distinguish genuine slow disk swapping from an admission deadlock.
    # Each '+' comes only after a distinct RUN child reports its real BRK.
    # Keep the original v1075 terminal markers byte-for-byte strict.
    admitted=$(printf '%s' "$text" | tr -cd '+' | wc -c | tr -d '[:space:]')
    if [ "$admitted" -ne 18 ]; then
        echo "v1207: only $admitted/18 RUN children acknowledged" >&2
        tail -25 "$work/simh.out" >&2
        exit 1
    fi
    reaped=$(printf '%s' "$text" | tr -cd '~' | wc -c | tr -d '[:space:]')
    if [ "$reaped" -ne 18 ]; then
        echo "v1207: only $reaped/18 RUN children reaped" >&2
        tail -25 "$work/simh.out" >&2
        exit 1
    fi
    text=$(printf '%s' "$text" | tr -d '+~^@%*?{}|')
fi
prefix=
if [ "$mm_fragment" = 1 ]; then prefix=F; fi
if [ "$mm_slots" = 1 ]; then prefix=M; fi
if [ "$run_cause" = 1 ]; then prefix=${prefix}C; fi
if [ "$combined" = 1 ]; then prefix=${prefix}A; fi
if [ "$bad_run" = 1 ]; then prefix=${prefix}R; fi
if [ "$negatives" = 1 ]; then prefix=${prefix}IL; fi
tail_marker=P
if [ "$pid_reuse" = 1 ]; then tail_marker=QP; fi
if [ "$disk_full" = 1 ]; then tail_marker=BMRP; fi
if [ "$endurance" = 1 ]; then
    tail_marker=EQP
    if [ "$enable" = 0 ]; then
        # Every one of 32 physical-OOM requesters returns normally and
        # prints D in the production-disabled guest. Do not skip or
        # wildcard those bytes: missing/extra completions must fail.
        returned=$(printf '%032d' 0 | tr 0 D)
        tail_marker=${returned}${tail_marker}
    fi
fi
if [ "$negatives" = 1 ]; then
    case "$text" in
        *"<$prefix"*'HALT'*) : ;;
        *) tail -70 "$work/simh.out" >&2
           echo 'v1110: invalid/address-limit BRK child did not return' >&2
           exit 1 ;;
    esac
fi
if [ "$enable" = 1 ]; then
    case "$text" in
        *"<${prefix}KW${tail_marker}"*'HALT'*) : ;;
        *) tail -70 "$work/simh.out" >&2
           echo 'v1075: missing requester-reclaimed / witness-survived markers' >&2
           exit 1 ;;
    esac
    case "$text" in
        *'!'*) tail -70 "$work/simh.out" >&2
               echo 'v1075: guest assertion failed' >&2; exit 1 ;;
    esac
    echo 'v1075: physical OOM kills requester only; blocked witness runs; MM accounting recovers PASS'
else
    case "$text" in
        *"<${prefix}DNW${tail_marker}"*'HALT'*) : ;;
        *) tail -70 "$work/simh.out" >&2
           echo 'v1075: default-off negative control failed' >&2
           exit 1 ;;
    esac
    echo 'v1075: default-off guest returns -1 rather than terminating requester PASS'
fi
if [ "$negatives" = 1 ]; then
    echo "v1110: invalid-floor and address-limit BRK return -1, preserve BRK and process MM (OOM enabled=$enable) PASS"
fi
if [ "$bad_run" = 1 ]; then
    echo "v1112: invalid child RUN rejected; no retained child slot or process-MM words, requester/witness survive (OOM enabled=$enable) PASS"
fi
if [ "$mm_slots" = 1 ]; then
    echo "v1114: real MM descriptor capacity filled, child RUN refused, original MM released (OOM enabled=$enable) PASS"
fi
if [ "$mm_fragment" = 1 ]; then
    echo "v1115: real physical MM fragmentation, BRK -1 with cause -2, no fatal requester, exact cleanup (OOM enabled=$enable) PASS"
fi
if [ "$run_cause" = 1 ]; then
    echo "v1116: real descriptor-saturated RUN returned -1 with original VM/MM cause -3, no retained child (OOM enabled=$enable) PASS"
fi
if [ "$combined" = 1 ]; then
    echo "v1158: independent RUN parent survives real -3 admission failure and remains live across physical requester OOM, with exact WAIT (OOM enabled=$enable) PASS"
fi
if [ "$pid_reuse" = 1 ]; then
    if [ "$endurance" = 1 ]; then
        echo "v1151: 32 additional true physical OOM/reclaim + successful RUN/BRK cycles, 256 PID reuse lifetimes, 512 stale requests and >=1024 actual PI6 ticks with stable MM/slot/backing PASS (OOM enabled=$enable)"
    else
        echo "v1120: 24 numeric PID reuse cycles, alternating exit statuses, stale WAIT/TERM rejection and exact MM/slot cleanup (OOM enabled=$enable) PASS"
    fi
fi
if [ "$disk_full" = 1 ]; then
    echo "v1156: real backing bitmap full, real allocation refusal, still-live BRK grow/shrink, subsequent backing recovery and stable process/FILE accounting PASS (OOM enabled=$enable)"
fi
if [ "$held_provider" = 1 ]; then
    python3 - "$work/addresses" "$work/simh.out" "$enable" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[2]).read_text(errors='replace')
seen = {}
for line in Path(sys.argv[1]).read_text().splitlines():
    name, addr = line.split()
    if name.startswith(('f07_', 'f07h_', 'f07p_', 'f07s_')):
        # v1203 has a separate, strict MM-snapshot verifier. Do not
        # flood the older v1150 provider-owner counter report with
        # up to 272 captured extent words.
        continue
    matches = re.findall(r'(?m)^\s*0*' + re.escape(addr.lstrip('0')) +
                         r'\s*:\s*([0-7]+)', text)
    if not matches:
        raise SystemExit('v1150: missing counter ' + name)
    seen[name] = int(matches[-1], 8)

one = ('holder_enter', 'holder_return', 'real_oom')
if any(seen[name] != 1 for name in one) or \
        seen['armed'] != (1 << 36) - 1 or \
        seen['release'] != (1 << 36) - 1:
    raise SystemExit('v1150: incorrect owner/oom counters ' + repr(seen))
if seen['holder_lease'] != (7 << 18) or \
        seen['lease_at_oom'] != (7 << 18) or \
        seen['predispatch'] < 1 or seen['spinner'] < 5 or \
        seen['error'] != 0:
    raise SystemExit('v1150: lease/waiter/spinner/OOM stage invalid: '
                     + repr(seen))
if sys.argv[3] == '1':
    if seen['fatal_busy'] < 2:
        raise SystemExit('v1150: OOM FILE close never retried: '+repr(seen))
elif seen['ordinary_wait'] < 1:
    raise SystemExit('v1150: disabled-OOM FILE close never waited: '
                     +repr(seen))
print('v1150: physical OOM under held in-flight FS lease and real '
      'pre-dispatch waiter, exact owner retry/release, independent '
      'spinner and MM accounting PASS:', seen)
PY
fi
if [ "$protected" = 1 ]; then
    python3 "$self/daimos-oom-protected-verify-v1159.py" \
        "$work/addresses" "$work/simh.out" "$enable" "$f07_swapslots"
fi
if [ "$f07_peak" = 1 ]; then
    python3 "$self/daimos-f07-mm-peak-verify-v1203.py" \
        "$work/addresses" "$work/simh.out" > "$work/f07-v1203.txt"
    cat "$work/f07-v1203.txt"
fi
if [ "$f07_high" = 1 ]; then
    if [ "$f07_combined" = 0 ]; then
        python3 "$self/daimos-f07-mm-high-verify-v1204.py" \
            "$work/addresses" "$work/simh.out" > "$work/f07h-v1204.txt"
        cat "$work/f07h-v1204.txt"
    fi
fi
if [ "$f07_concurrent" = 1 ]; then
    python3 "$self/daimos-f07-real-proc-verify-v1205.py" \
        "$work/addresses" "$work/simh.out" > "$work/f07p-v1205.txt"
    cat "$work/f07p-v1205.txt"
fi
if [ "$f07_swapslots" = 1 ]; then
    python3 "$self/daimos-f07-swapstack-verify-v1207.py" \
        "$work/addresses" "$work/simh.out" > "$work/f07s-v1207.txt"
    cat "$work/f07s-v1207.txt"
fi
if [ "$f07_combined" = 1 ]; then
    python3 "$self/daimos-f07-combined-verify-v1206.py" \
        "$work/addresses" "$work/simh.out" > "$work/f07c-v1206.txt"
    cat "$work/f07c-v1206.txt"
fi
if [ "$residency" = 1 ]; then
    # Retain raw independent observations if the new audit fails.  The
    # outer versioned E13 directory survives the disposable guest trap.
    e=$V1160_EVIDENCE_DIR
    test ! -e "$e" || { echo "v1174: evidence exists: $e" >&2; exit 2; }
    mkdir -p "$e"
    cp "$work/simh.out" "$e/simh.out"
    cp "$work/addresses" "$e/addresses"
    cp "$build/kcore.map" "$e/kcore.map"
    cp "$build/boot.ini" "$e/boot.ini"
    python3 "$self/daimos-oom-residency-verify-v1174.py" \
        "$work/addresses" "$work/simh.out" "$build/kcore.map" \
        > "$work/residency-v1174.txt"
    cat "$work/residency-v1174.txt"
    : > "$work/mres-packages-v1174.txt"
    for pkg in "$build"/*-mres.dobj; do
        test -f "$pkg" || continue
        "$PDP10_PREFIX/bin/pdp10-objdump" -h "$pkg" \
            | sed "s@^@$(basename "$pkg") @" \
            >> "$work/mres-packages-v1174.txt"
    done
fi
if [ "$release_media" = 1 ]; then
    # Archive *complete* build/simulator/counter evidence, not just a PASS
    # summary. Media is hashed but not copied into the small evidence bundle.
    # This runs only after all production-path guest validations have passed.
    e=$V1160_EVIDENCE_DIR
    if [ "$residency" != 1 ]; then
        test ! -e "$e" || { echo "v1160: evidence exists: $e" >&2; exit 2; }
        mkdir -p "$e"
    fi
    cp "$work/build.log" "$e/build.log"
    cp "$work/simh.out" "$e/simh.out"
    cp "$work/addresses" "$e/addresses"
    cp "$build/boot.ini" "$e/boot.ini"
    cp "$build/kcore.map" "$e/kcore.map"
    cp "$work/user/init.map" "$e/init.map"
    if [ "$residency" = 1 ]; then
        cp "$work/residency-v1174.txt" "$e/residency-v1174.txt"
        cp "$work/mres-packages-v1174.txt" "$e/mres-packages-v1174.txt"
    fi
    if [ "$f07_peak" = 1 ]; then
        cp "$work/f07-v1203.txt" "$e/f07-v1203.txt"
    fi
    if [ "$f07_high" = 1 ] && [ "$f07_combined" = 0 ]; then
        cp "$work/f07h-v1204.txt" "$e/f07h-v1204.txt"
    fi
    if [ "$f07_concurrent" = 1 ]; then
        cp "$work/f07p-v1205.txt" "$e/f07p-v1205.txt"
    fi
    if [ "$f07_swapslots" = 1 ]; then
        cp "$work/f07s-v1207.txt" "$e/f07s-v1207.txt"
    fi
    if [ "$f07_combined" = 1 ]; then
        cp "$work/f07c-v1206.txt" "$e/f07c-v1206.txt"
    fi
    printf 'mode=%s\n' "$enable" > "$e/profile.txt"
    printf 'boot=dsk\nroot=disk\nrootset=1\n' >> "$e/profile.txt"
    printf 'profile=full\ncore_octal=01000000\n' >> "$e/profile.txt"
    printf 'simulator_kwords=256\ncompiler=kcc\n' >> "$e/profile.txt"
    printf 'wall_clock_hz=60\npclk=REALTIME\ndpy=HEADLESS\n' >> "$e/profile.txt"
    printf 'console=CTY\nwcnsls=disabled\nocnsls=disabled\n' >> "$e/profile.txt"
    printf 'production_oom=OFF\ntest_only_oom=%s\n' "$enable" >> "$e/profile.txt"
    printf 'daimos_commit=%s\n' "$(git -C "$DAIMOS_REPO" rev-parse HEAD)" >> "$e/profile.txt"
    printf 'testkit_commit=%s\n' "$(git -C "$self/../.." rev-parse HEAD)" >> "$e/profile.txt"
    grep -q '^set cpu 256k$' "$e/boot.ini"
    grep -q '^deposit SW 1$' "$e/boot.ini"
    grep -q '^set pclk REALTIME$' "$e/boot.ini"
    grep -q '^set wcnsls disabled$' "$e/boot.ini"
    grep -q '^set ocnsls disabled$' "$e/boot.ini"
    grep -q 'D6FS.*LOADED' "$e/simh.out"
    disk0=$(awk '$1 == "attach" && $2 == "-q" && $3 == "dsk0" { print $4 }' "$e/boot.ini")
    test -n "$disk0" && test -f "$disk0"
    sha256sum "$disk0" > "$e/media-sha256.txt"
    for tool in pdp6 das dlink p10fold kcc pdp10-dec-none-gcc; do
        test -x "$PDP10_PREFIX/bin/$tool"
        sha256sum "$PDP10_PREFIX/bin/$tool" >> "$e/host-tools-sha256.txt"
    done
    (cd "$e" && sha256sum build.log simh.out addresses boot.ini \
        kcore.map init.map profile.txt > evidence-sha256.txt)
    if [ "$residency" = 1 ]; then
        (cd "$e" && sha256sum residency-v1174.txt mres-packages-v1174.txt \
            >> evidence-sha256.txt)
    fi
    if [ "$f07_peak" = 1 ]; then
        (cd "$e" && sha256sum f07-v1203.txt >> evidence-sha256.txt)
    fi
    if [ "$f07_high" = 1 ] && [ "$f07_combined" = 0 ]; then
        (cd "$e" && sha256sum f07h-v1204.txt >> evidence-sha256.txt)
    fi
    if [ "$f07_concurrent" = 1 ]; then
        (cd "$e" && sha256sum f07p-v1205.txt >> evidence-sha256.txt)
    fi
    if [ "$f07_swapslots" = 1 ]; then
        (cd "$e" && sha256sum f07s-v1207.txt >> evidence-sha256.txt)
    fi
    if [ "$f07_combined" = 1 ]; then
        (cd "$e" && sha256sum f07c-v1206.txt >> evidence-sha256.txt)
    fi
    echo "v1160: explicit 256K KCC DSK/D6FS physical-OOM release-media evidence PASS: $e"
fi
