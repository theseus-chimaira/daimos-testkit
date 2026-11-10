#!/bin/sh
# Verify all four MM rollback/finalization refusal cases with native KCC.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR="${TMPDIR:-$HOME/tmp}" PDP10_PREFIX
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-pure-rollback-v1395.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
src="$DAIMOS_REPO/system/kernel"
include="-I$src/proc -I$src/core -I$src/mm -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include -I$testkit/tests/validation/pure-ram-lifecycle-v1377 -I$testkit/tests/validation/pure-ram-registryfree-v1379 -I$testkit/tests/validation/pure-ram-inplace-v1381 -I$testkit/tests/validation/pure-ram-prefix-v1384"
for spec in 'proc_pure_ram_v1381 DAIMOS_SWAPLESS_PURE_RAM_V1381' 'proc_pure_restore_v1384 DAIMOS_SWAPLESS_PREFIX_V1384'; do
    set -- $spec
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -D"$2"=1 $include -S "$src/proc/$1.c" -o "$work/$1.s"
done
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_SWAPLESS_PURE_RAM_RESTORE_V1391=1 \
    -Dmm_unpin=mm_unpin_fault_v1395 -Dmm_free=mm_free_fault_v1395 \
    $include -S "$src/proc/proc_pure_ram_restore_v1391.c" \
    -o "$work/proc-pure-restore-v1395.s"
{
    printf '#define DAIMOS_TEST_PURE_ROLLBACK_V1395 1\n'
    cat "$testkit/tests/validation/pure-ram-prefix-v1384/test-native-v1384.c" \
        "$testkit/tests/validation/pure-ram-rollback-v1395/test-native-v1395.c"
} > "$work/combined-native-v1395.c"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $include \
    -S "$work/combined-native-v1395.c" \
    -o "$work/test-native-v1395.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/guest" --name pure-rollback-v1395 \
    --expect __test_exit=0 "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/proc_pure_ram_v1381.s" "$work/proc_pure_restore_v1384.s" \
    "$work/proc-pure-restore-v1395.s" \
    "$src/mm/mm_pure_rebase_v1381.s" "$src/mm/mm_pure_expand_v1384.s" \
    "$src/proc/proc_storage_runtime_v30.s" "$work/test-native-v1395.s"
echo 'PASS v1395: native PURE restore rollback and finish failure isolation'
