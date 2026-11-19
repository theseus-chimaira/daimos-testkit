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
work=$(mktemp -d "$TMPDIR/daimos-pure-mm-precommit-v1678.XXXXXX")
trap 'echo "v1678 native evidence: $work"' EXIT HUP INT TERM
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
    cat "$here/test-native-v1678.c"
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

run_guest pure-mm-precommit-v1678 "$src/mm/mm_pure_expand_v1384.s" \
    "$work/native-pass.log" || {
    tail -90 "$work/native-pass.log" >&2
    exit 1
}
echo 'PASS v1678: original MM pin/rebase refusals, no pin leaks, two-owner restore/retry'
# Native source-authentic negative cases run the SAME v1678 oracle.
python3 - "$src/proc/proc_pure_ram_v1381.c" \
    "$src/proc/proc_pure_service_pdp6_v1612.c" \
    "$work/unsafe-drop.c" "$work/unsafe-service.c" <<'PYV1678MUT'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text(encoding='ascii')
old='''                if (mm_unpin(source) != MM_OK)
                        return MM_ERR_BUSY;'''
new='''                /* INVALID mutant: leaked source pin on rejected rebase. */
                if (0)
                        return MM_ERR_BUSY;'''
if src.count(old)!=1:
    raise SystemExit('v1678 source cleanup unpin changed')
Path(sys.argv[3]).write_text(src.replace(old,new,1),encoding='ascii')
src=Path(sys.argv[2]).read_text(encoding='ascii')
old='''                        if (ppure_retryable_v1612(slot, p,
                            PROC_STORAGE_RESIDENT)) {
                                PROC_CLEAR_TRANSITION(p);'''
new='''                        if (ppure_retryable_v1612(slot, p,
                            PROC_STORAGE_RESIDENT)) {
                                /* INVALID: clean owner still held. */
                                (void)p;'''
if src.count(old)!=1:
    raise SystemExit('v1678 source resident TRANSITION guard changed')
Path(sys.argv[4]).write_text(src.replace(old,new,1),encoding='ascii')
PYV1678MUT
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 \
    '-Dmm_unpin=mm_unpin_fault_v1677' \
    '-Dmm_pin=mm_pin_fault_v1678' \
    '-Dmm_pure_rebase_pinned_v1381=mm_pure_rebase_fault_v1678' \
    $inc -S "$work/unsafe-drop.c" -o "$work/unsafe-drop.s" \
    >"$work/unsafe-drop-build.log" 2>&1 || {
    cat "$work/unsafe-drop-build.log" >&2
    exit 1
}
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    $inc -S "$work/unsafe-service.c" -o "$work/unsafe-service.s" \
    >"$work/unsafe-service-build.log" 2>&1 || {
    cat "$work/unsafe-service-build.log" >&2
    exit 1
}
if run_guest unsafe-leaked-pin-v1678 "$src/mm/mm_pure_expand_v1384.s" \
    "$work/unsafe-leaked-pin.log" "$work/unsafe-drop.s" \
    "$work/service.s"; then
    echo 'FAIL v1678: unsafe cleanup pin leak survived original MM oracle' >&2
    exit 1
fi
if ! grep -q '^FAIL: __test_exit: got 000000001201 ' \
    "$work/unsafe-leaked-pin.log"; then
    tail -60 "$work/unsafe-leaked-pin.log" >&2
    echo 'FAIL v1678: pin leak negative failed for wrong reason' >&2
    exit 1
fi
echo 'PASS v1678: executed missing-rebase-cleanup-unpin mutant rejected'
if run_guest unsafe-transition-v1678 "$src/mm/mm_pure_expand_v1384.s" \
    "$work/unsafe-transition.log" "$work/proc_pure_ram_v1381.s" \
    "$work/unsafe-service.s"; then
    echo 'FAIL v1678: unsafe resident TRANSITION retention accepted' >&2
    exit 1
fi
if ! grep -q '^FAIL: __test_exit: got 000000001101 ' \
    "$work/unsafe-transition.log"; then
    tail -60 "$work/unsafe-transition.log" >&2
    echo 'FAIL v1678: TRANSITION negative failed for wrong reason' >&2
    exit 1
fi
echo 'PASS v1678: executed missing-resident-TRANSITION-release mutant rejected'
