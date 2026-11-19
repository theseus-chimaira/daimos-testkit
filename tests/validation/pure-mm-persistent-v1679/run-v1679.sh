#!/bin/sh
# Native PDP-6 original MM pin/rebase precommit fault and recovery.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/daimos-pure-mm-persistent-v1679.XXXXXX")
trap 'echo "v1679 native evidence: $work"' EXIT HUP INT TERM
inc="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include -I$testkit/tests/validation/pure-ram-lifecycle-v1377 -I$testkit/tests/validation/pure-ram-registryfree-v1379 -I$testkit/tests/validation/pure-ram-inplace-v1381"

sh "$testkit/tests/validation/pure-full-commit-v1654/run-v1654.sh" >"$work/v1654-baseline.log" 2>&1
sh "$testkit/tests/validation/pure-service-v1612/run-v1612.sh" >"$work/v1612-baseline.log" 2>&1
echo 'v1658: original FULL fault and source-linked service baselines PASS'

for spec in \
    'proc_pure_ram_v1381 DAIMOS_SWAPLESS_PURE_RAM_V1381' \
    'proc_pure_restore_v1384 DAIMOS_SWAPLESS_PREFIX_V1384' \
    'proc_pure_ram_restore_v1391 DAIMOS_PURE_FULL_V1391'; do
    set -- $spec
    extra=
    if [ "$1" = proc_pure_ram_v1381 ]; then
        extra='-Dmm_unpin=mm_unpin_fault_v1677 -Dmm_pin=mm_pin_fault_v1678 -Dmm_pure_rebase_pinned_v1381=mm_pure_rebase_fault_v1678'
    fi
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -D"$2"=1 $extra $inc -S "$src/proc/$1.c" \
        -o "$work/$1.s" >"$work/$1.log" 2>&1 || {
        cat "$work/$1.log" >&2
        exit 1
    }
done
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc \
    -S "$src/proc/proc_pure_service_pdp6_v1612.c" \
    -o "$work/service.s" >"$work/service.log" 2>&1 || {
    cat "$work/service.log" >&2
    exit 1
}
{
    printf '#define DAIMOS_TEST_PURE_ROLLBACK_V1395 1\n'
    cat "$testkit/tests/validation/pure-ram-prefix-v1384/test-native-v1384.c"
    printf '#define main baseline_main_v1658\n'
    printf '#define exec_image_prefix_backing_v1386 exec_image_prefix_fixture_v1611\n'
    cat "$testkit/tests/validation/pure-service-v1611/test-native-v1611.c"
    printf '#undef exec_image_prefix_backing_v1386\n'
    printf '#undef main\n'
    printf '#define main baseline_main_v1677\n'
    cat "$testkit/tests/validation/pure-mm-owner-v1658/test-native-v1658.c"
    printf '#undef main\n'
    printf '#define main baseline_main_v1678\n'
    cat "$testkit/tests/validation/pure-pi6-fault-pressure-v1677/test-native-v1677.c"
    printf '#undef main\n'
    printf '#define main baseline_main_v1679\n'
    cat "$testkit/tests/validation/pure-mm-precommit-v1678/test-native-v1678.c"
    printf '#undef main\n'
    cat "$here/test-native-v1679.c"
} >"$work/test.c"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_TEST_PURE_SERVICE_V1612=1 \
    -Dproc_pure_mres_reclaim_v1611=proc_pure_mres_reclaim_v1612 \
    -Dproc_pure_mres_service_v1611=proc_pure_mres_service_v1612 \
    $inc -S "$work/test.c" -o "$work/test.s" \
    >"$work/test.log" 2>&1 || {
    cat "$work/test.log" >&2
    exit 1
}

run_guest() {
    name=$1
    mmfile=$2
    target=$3
    drop=${4:-$work/proc_pure_ram_v1381.s}
    service=${5:-$work/service.s}
    mkdir -p "$work/$name"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/$name" --name "$name" --expect __test_exit=0 \
        "$testkit/tests/validation/daimos-test-crt0-v1.s" \
        "$drop" \
        "$work/proc_pure_restore_v1384.s" \
        "$work/proc_pure_ram_restore_v1391.s" \
        "$service" \
        "$src/mm/mm_pure_rebase_v1381.s" \
        "$mmfile" \
        "$src/proc/proc_storage_runtime_v30.s" \
        "$src/drivers/device_state.s" \
        "$work/test.s" >"$target" 2>&1
}

run_guest pure-mm-persistent-v1679 "$src/mm/mm_pure_expand_v1384.s" \
    "$work/native-pass.log" || {
    tail -90 "$work/native-pass.log" >&2
    exit 1
}
echo 'PASS v1679: four genuine MM refusals per owner, healthy bystander and retry'

# Two original source regressions must fail in the *new* repeated-refusal
# oracle, with exact distinct native guest codes rather than a timeout.
python3 - "$src/proc/proc_pure_ram_v1381.c" \
    "$src/proc/proc_pure_service_pdp6_v1612.c" \
    "$work/unsafe-drop-v1679.c" "$work/unsafe-service-v1679.c" <<'PYV1679MUT'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text(encoding='ascii')
old='''                if (mm_unpin(source) != MM_OK)
                        return MM_ERR_BUSY;'''
new='''                /* INVALID: original failed rebase leaks its pin. */
                if (0)
                        return MM_ERR_BUSY;'''
if src.count(old) != 1:
    raise SystemExit('v1679 source precommit unpin anchor drift')
Path(sys.argv[3]).write_text(src.replace(old,new,1),encoding='ascii')
src=Path(sys.argv[2]).read_text(encoding='ascii')
old='''                        if (ppure_retryable_v1612(slot, p,
                            PROC_STORAGE_RESIDENT)) {
                                PROC_CLEAR_TRANSITION(p);'''
new='''                        if (ppure_retryable_v1612(slot, p,
                            PROC_STORAGE_RESIDENT)) {
                                /* INVALID: publication without MM rebase. */
                                VM_PDP6_SET_BASE(p, 0UL);
                                PROC_CLEAR_TRANSITION(p);'''
if src.count(old) != 1:
    raise SystemExit('v1679 resident mode retry anchor drift')
Path(sys.argv[4]).write_text(src.replace(old,new,1),encoding='ascii')
PYV1679MUT
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 \
    -Dmm_unpin=mm_unpin_fault_v1677 \
    -Dmm_pin=mm_pin_fault_v1678 \
    -Dmm_pure_rebase_pinned_v1381=mm_pure_rebase_fault_v1678 \
    $inc -S "$work/unsafe-drop-v1679.c" -o "$work/unsafe-drop-v1679.s" \
    >"$work/unsafe-drop-build.log" 2>&1 || {
    cat "$work/unsafe-drop-build.log" >&2; exit 1;
}
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc \
    -S "$work/unsafe-service-v1679.c" \
    -o "$work/unsafe-service-v1679.s" \
    >"$work/unsafe-service-build.log" 2>&1 || {
    cat "$work/unsafe-service-build.log" >&2; exit 1;
}
if run_guest unsafe-leaked-pin-v1679 "$src/mm/mm_pure_expand_v1384.s" \
    "$work/unsafe-leaked-pin.log" "$work/unsafe-drop-v1679.s" \
    "$work/service.s"; then
    echo 'FAIL v1679: persistent source pin leak survived' >&2; exit 1
fi
if ! grep -q '^FAIL: __test_exit: got 000000003201 ' \
    "$work/unsafe-leaked-pin.log"; then
    tail -65 "$work/unsafe-leaked-pin.log" >&2
    echo 'FAIL v1679: pin leak did not fail rebase case 2' >&2; exit 1
fi
echo 'PASS v1679: executed source pin-leak mutant rejected at case 2'
if run_guest unsafe-resident-apr-v1679 \
    "$src/mm/mm_pure_expand_v1384.s" \
    "$work/unsafe-resident-apr.log" \
    "$work/proc_pure_ram_v1381.s" "$work/unsafe-service-v1679.s"; then
    echo 'FAIL v1679: corrupt RESIDENT APR survived' >&2; exit 1
fi
if ! grep -q '^FAIL: __test_exit: got 000000003101 ' \
    "$work/unsafe-resident-apr.log"; then
    tail -65 "$work/unsafe-resident-apr.log" >&2
    echo 'FAIL v1679: unsafe APR mutation not caught by case 1' >&2; exit 1
fi
echo 'PASS v1679: executed premature APR clear mutant rejected at case 1'
