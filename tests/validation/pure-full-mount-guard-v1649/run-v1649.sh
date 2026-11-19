#!/bin/sh
# PDP-6 native source-linked v1391 FULL + exact production mount guard.
# Runs earlier v1395/v1648 rollback tests before the new pinned checkpoint.
set -eu
: "${DAIMOS_REPO:?original DAIMOS source required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-pure-full-mount-v1649.XXXXXX")
trap 'echo "v1649 native evidence: $work"' EXIT HUP INT TERM
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
            -D"$2"=1 $include -S "$src/proc/$1.c" -o "$work/$1.s"
    fi
done
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_PURE_FULL_V1391=1 \
    -Dmm_unpin=mm_unpin_fault_v1395 \
    -Dmm_free=mm_free_fault_v1648 \
    -Dmm_pin=mm_pin_fault_v1648 \
    $include -S "$src/proc/proc_pure_ram_restore_v1391.c" \
    -o "$work/production-full-v1649.s"
{
    printf '#define DAIMOS_TEST_PURE_ROLLBACK_V1395 1\n'
    cat "$testkit/tests/validation/pure-ram-prefix-v1384/test-native-v1384.c"
    printf '#define main baseline_main_v1395\n'
    cat "$testkit/tests/validation/pure-ram-rollback-v1395/test-native-v1395.c"
    printf '#undef main\n#define main baseline_main_v1648\n'
    cat "$testkit/tests/validation/pure-full-atomic-v1648/test-native-v1648.c"
    printf '#undef main\n'
    cat "$here/test-native-v1649.c"
} >"$work/combined-native-v1649.c"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $include \
    -S "$work/combined-native-v1649.c" -o "$work/test-native-v1649.s"

for variant in none mount backing; do
    python3 "$here/extract-guard-v1649.py" \
        "$src/proc/proc_pure_backing_pdp6.s" \
        "$work/guard-$variant-v1649.s" "$variant"
done

run_one() {
    variant=$1
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/guest-$variant" \
        --name "pure-full-guard-$variant-v1649" \
        --expect __test_exit=0 \
        "$testkit/tests/validation/daimos-test-crt0-v1.s" \
        "$work/proc_pure_ram_v1381.s" \
        "$work/proc_pure_restore_v1384.s" \
        "$work/production-full-v1649.s" \
        "$src/mm/mm_pure_rebase_v1381.s" \
        "$src/mm/mm_pure_expand_v1384.s" \
        "$src/proc/proc_storage_runtime_v30.s" \
        "$src/drivers/device_state.s" \
        "$work/guard-$variant-v1649.s" \
        "$work/test-native-v1649.s" \
        >"$work/result-$variant.log" 2>&1
}

if ! run_one none; then
    tail -50 "$work/result-none.log" >&2
    echo 'FAIL v1649: original production guard during pinned FULL' >&2
    exit 1
fi
echo 'PASS v1649: source-linked PINNED RAW + FULL APR, both original guards'
for variant in mount backing; do
    if run_one "$variant"; then
        echo "FAIL v1649: unsafe $variant guard accepted" >&2
        exit 1
    fi
    if ! grep -q '^FAIL: __test_exit: got ' "$work/result-$variant.log"; then
        tail -40 "$work/result-$variant.log" >&2
        echo "FAIL v1649: $variant negative control did not execute" >&2
        exit 1
    fi
    echo "PASS v1649: native invalid $variant guard rejected"
done
