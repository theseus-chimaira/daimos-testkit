#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
work="$TMPDIR/pure-ram-prefix-v1384-native"
mkdir -p "$work"
include="-I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/storage -I$DAIMOS_REPO/system/kernel/modules -I$DAIMOS_REPO/system/kernel/drivers -I$PDP10_PREFIX/include -I$testkit/tests/validation/pure-ram-lifecycle-v1377 -I$testkit/tests/validation/pure-ram-registryfree-v1379 -I$testkit/tests/validation/pure-ram-inplace-v1381"
for src in proc_pure_ram_v1381 proc_pure_restore_v1384; do
    case "$src" in
        proc_pure_ram_v1381) flag=DAIMOS_SWAPLESS_PURE_RAM_V1381 ;;
        *) flag=DAIMOS_SWAPLESS_PREFIX_V1384 ;;
    esac
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -D"$flag"=1 $include \
        -S "$DAIMOS_REPO/system/kernel/proc/$src.c" -o "$work/$src.s"
done
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $include \
    -S "$testkit/tests/validation/pure-ram-prefix-v1384/test-native-v1384.c" \
    -o "$work/test-native-v1384.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/guest" --name pure-ram-prefix-v1384 \
    --expect __test_exit=0 \
    --examine diag_release_v1384 --examine diag_extent_span_v1384 \
    --examine diag_extent_meta_v1384 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/proc_pure_ram_v1381.s" \
    "$work/proc_pure_restore_v1384.s" \
    "$DAIMOS_REPO/system/kernel/mm/mm_pure_rebase_v1381.s" \
    "$DAIMOS_REPO/system/kernel/mm/mm_pure_expand_v1384.s" \
    "$DAIMOS_REPO/system/kernel/proc/proc_storage_runtime_v30.s" \
    "$work/test-native-v1384.s"
