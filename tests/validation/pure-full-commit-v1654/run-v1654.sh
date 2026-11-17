#!/bin/sh
# Native original PDP-6 atomic source ownership and target-unpin ordering.
set -eu
: "${DAIMOS_REPO:?source DAIMOS repository required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/daimos-pure-full-commit-v1654.XXXXXX")
trap 'echo "v1654 native commit evidence: $work"' EXIT HUP INT TERM
sh "$testkit/tests/validation/pure-ram-rollback-v1395/run-v1395.sh" >"$work/v1395-baseline.log" 2>&1
sh "$testkit/tests/validation/pure-full-atomic-v1648/run-v1648.sh" >"$work/v1648-baseline.log" 2>&1
echo 'PASS v1654: native PDP-6 v1395/v1397 and v1648 rollback/retry matrix'

# The OLD post-commit failure path must execute and be rejected by the
# revised native fault oracle. It must not merely fail compilation.
python3 "$here/mutate-v1654.py" "$src/proc/proc_pure_ram_restore_v1391.c" "$work/full-postcommit-bad-v1654.c"
include="-I$src/proc -I$src/core -I$src/mm -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include -I$testkit/tests/validation/pure-ram-lifecycle-v1377 -I$testkit/tests/validation/pure-ram-registryfree-v1379 -I$testkit/tests/validation/pure-ram-inplace-v1381 -I$testkit/tests/validation/pure-ram-prefix-v1384"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas -DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 -Dmm_unpin=mm_unpin_fault_v1395 -Dmm_pure_rebase_pinned_v1381=mm_pure_rebase_fault_v1397 $include -S "$src/proc/proc_pure_ram_v1381.c" -o "$work/pure-drop-v1654.s" >"$work/drop-compile.log" 2>&1
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas -DDAIMOS_SWAPLESS_PREFIX_V1384=1 $include -S "$src/proc/proc_pure_restore_v1384.c" -o "$work/pure-prefix-v1654.s" >"$work/prefix-compile.log" 2>&1
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas -DDAIMOS_PURE_FULL_V1391=1 -Dmm_unpin=mm_unpin_fault_v1395 -Dmm_free=mm_free_fault_v1395 $include -S "$work/full-postcommit-bad-v1654.c" -o "$work/full-postcommit-bad-v1654.s" >"$work/mutant-compile.log" 2>&1
{
    printf '#define DAIMOS_TEST_PURE_ROLLBACK_V1395 1\n'
    cat "$testkit/tests/validation/pure-ram-prefix-v1384/test-native-v1384.c" "$testkit/tests/validation/pure-ram-rollback-v1395/test-native-v1395.c"
} >"$work/test-native-v1654.c"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $include -S "$work/test-native-v1654.c" -o "$work/test-native-v1654.s" >"$work/fixture-compile.log" 2>&1
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$work/guest-old-order" --name pure-full-postcommit-bad-v1654 --expect __test_exit=0 "$testkit/tests/validation/daimos-test-crt0-v1.s" "$work/pure-drop-v1654.s" "$work/pure-prefix-v1654.s" "$work/full-postcommit-bad-v1654.s" "$src/mm/mm_pure_rebase_v1381.s" "$src/mm/mm_pure_expand_v1384.s" "$src/proc/proc_storage_runtime_v30.s" "$src/drivers/device_state.s" "$work/test-native-v1654.s" >"$work/old-order-run.log" 2>&1; then
    echo 'FAIL v1654: old source-free-before-target-unpin was accepted' >&2
    exit 1
fi
if ! grep -q '^FAIL: __test_exit: got ' "$work/old-order-run.log"; then
    cat "$work/old-order-run.log" >&2
    echo 'FAIL v1654: old-order mutant did not reach native MM oracle' >&2
    exit 1
fi
echo 'PASS v1654: executed old post-publication target unpin rejected on native PDP-6'

# The two permanently refused MM unpins exercise the real compiled
# FULL transaction. Neither can unlock or publish the process. A
# transient target refusal was already checked by the v1395 baseline.
{
    printf '#define DAIMOS_TEST_PURE_ROLLBACK_V1395 1\n'
    cat "$testkit/tests/validation/pure-ram-prefix-v1384/test-native-v1384.c"
    printf '#define main baseline_main_v1395\n'
    cat "$testkit/tests/validation/pure-ram-rollback-v1395/test-native-v1395.c"
    printf '#undef main\n'
    cat "$here/test-native-v1654.c"
} >"$work/combined-native-v1654.c"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $include -S "$work/combined-native-v1654.c" -o "$work/test-uncertain-v1654.s" >"$work/uncertain-compile.log" 2>&1
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas -DDAIMOS_PURE_FULL_V1391=1 -Dmm_unpin=mm_unpin_fault_v1395 -Dmm_free=mm_free_fault_v1395 $include -S "$src/proc/proc_pure_ram_restore_v1391.c" -o "$work/full-original-v1654.s" >"$work/original-compile.log" 2>&1
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$work/guest-uncertain" --name pure-full-uncertain-v1654 --expect __test_exit=0 "$testkit/tests/validation/daimos-test-crt0-v1.s" "$work/pure-drop-v1654.s" "$work/pure-prefix-v1654.s" "$work/full-original-v1654.s" "$src/mm/mm_pure_rebase_v1381.s" "$src/mm/mm_pure_expand_v1384.s" "$src/proc/proc_storage_runtime_v30.s" "$src/drivers/device_state.s" "$work/test-uncertain-v1654.s" >"$work/uncertain-run.log" 2>&1 || { tail -60 "$work/uncertain-run.log" >&2; exit 1; }
echo 'PASS v1654: permanent target/source unpin refusals preserve PACKED authority'
