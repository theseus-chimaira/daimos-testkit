#!/bin/sh
# Real native PDP-6 KCC FULL transaction: independent source-free and
# new-target pin refusals, exact RAW rollback and later successful retry.
set -eu
: "${DAIMOS_REPO:?production DAIMOS source checkout required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-pure-full-atomic-v1648.XXXXXX")
trap 'echo "v1648 native evidence: $work"' EXIT HUP INT TERM
src="$DAIMOS_REPO/system/kernel"
include="-I$src/proc -I$src/core -I$src/mm -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include -I$testkit/tests/validation/pure-ram-lifecycle-v1377 -I$testkit/tests/validation/pure-ram-registryfree-v1379 -I$testkit/tests/validation/pure-ram-inplace-v1381 -I$testkit/tests/validation/pure-ram-prefix-v1384"
for spec in 'proc_pure_ram_v1381 DAIMOS_SWAPLESS_PURE_RAM_V1381' 'proc_pure_restore_v1384 DAIMOS_SWAPLESS_PREFIX_V1384'; do
    set -- $spec
    if [ "$1" = proc_pure_ram_v1381 ]; then
        "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
            -D"$2"=1 -Dmm_unpin=mm_unpin_fault_v1395 \
            -Dmm_pure_rebase_pinned_v1381=mm_pure_rebase_fault_v1397 \
            $include -S "$src/proc/$1.c" -o "$work/$1.s"
    else
        "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
            -D"$2"=1 $include -S "$src/proc/$1.c" \
            -o "$work/$1.s"
    fi
done
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_PURE_FULL_V1391=1 \
    -Dmm_unpin=mm_unpin_fault_v1395 \
    -Dmm_free=mm_free_fault_v1648 \
    -Dmm_pin=mm_pin_fault_v1648 \
    $include -S "$src/proc/proc_pure_ram_restore_v1391.c" \
    -o "$work/proc-pure-restore-v1648.s"
{
    printf '#define DAIMOS_TEST_PURE_ROLLBACK_V1395 1\n'
    cat "$testkit/tests/validation/pure-ram-prefix-v1384/test-native-v1384.c"
    printf '#define main baseline_main_v1395\n'
    cat "$testkit/tests/validation/pure-ram-rollback-v1395/test-native-v1395.c"
    printf '#undef main\n'
    cat "$here/test-native-v1648.c"
} > "$work/combined-native-v1648.c"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $include \
    -S "$work/combined-native-v1648.c" \
    -o "$work/test-native-v1648.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/guest" --name pure-full-atomic-v1648 \
    --expect __test_exit=0 "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/proc_pure_ram_v1381.s" \
    "$work/proc_pure_restore_v1384.s" \
    "$work/proc-pure-restore-v1648.s" \
    "$src/mm/mm_pure_rebase_v1381.s" \
    "$src/mm/mm_pure_expand_v1384.s" \
    "$src/proc/proc_storage_runtime_v30.s" \
    "$DAIMOS_REPO/system/kernel/drivers/device_state.s" \
    "$work/test-native-v1648.s"
echo 'PASS v1648: native FULL source-free/pin faults retain RAW and exact retry'
echo 'v1648: source free BUSY, source free INVAL, target pin BUSY'

# Negative controls must link and execute the SAME native regression.
# Only a disposable copy of the actual production C transaction changes.
# A broken candidate must execute and fail the zero-exit oracle, not
# merely fail to assemble or link.
for mutation in overlay target-free; do
    python3 "$here/mutate-v1648.py" \
        "$src/proc/proc_pure_ram_restore_v1391.c" "$mutation" \
        "$work/full-mutant-$mutation.c"
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -DDAIMOS_PURE_FULL_V1391=1 \
        -Dmm_unpin=mm_unpin_fault_v1395 \
        -Dmm_free=mm_free_fault_v1648 \
        -Dmm_pin=mm_pin_fault_v1648 \
        $include -S "$work/full-mutant-$mutation.c" \
        -o "$work/full-mutant-$mutation.s" \
        >"$work/mutant-compile-$mutation.log" 2>&1
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/guest-$mutation" \
        --name "pure-full-mutant-v1648-$mutation" \
        --expect __test_exit=0 \
        "$testkit/tests/validation/daimos-test-crt0-v1.s" \
        "$work/proc_pure_ram_v1381.s" \
        "$work/proc_pure_restore_v1384.s" \
        "$work/full-mutant-$mutation.s" \
        "$src/mm/mm_pure_rebase_v1381.s" \
        "$src/mm/mm_pure_expand_v1384.s" \
        "$src/proc/proc_storage_runtime_v30.s" \
        "$DAIMOS_REPO/system/kernel/drivers/device_state.s" \
        "$work/test-native-v1648.s" \
        >"$work/mutant-run-$mutation.log" 2>&1; then
        echo "FAIL v1648: invalid $mutation transaction passed" >&2
        exit 1
    fi
    if ! grep -q '^FAIL: __test_exit: got ' \
        "$work/mutant-run-$mutation.log"; then
        cat "$work/mutant-run-$mutation.log" >&2
        echo "FAIL v1648: $mutation was not a running negative control" >&2
        exit 1
    fi
    echo "PASS v1648: invalid $mutation transaction rejected"
done
