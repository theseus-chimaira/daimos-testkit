#!/bin/sh
# Actual resident PURE guards combined with the zero-copy MM descriptor
# converter, which preserves the saved backing source throughout.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
work="$TMPDIR/pure-ram-backing-v1382-native"
mkdir -p "$work"
include="-I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/storage -I$DAIMOS_REPO/system/kernel/modules -I$DAIMOS_REPO/system/kernel/drivers -I$PDP10_PREFIX/include -I$testkit/tests/validation/pure-ram-lifecycle-v1377"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 $include \
    -S "$DAIMOS_REPO/system/kernel/proc/proc_pure_ram_v1381.c" \
    -o "$work/proc_pure_ram_v1381.s"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_TEST_FIXTURE_NO_MAIN=1 \
    -DDAIMOS_TEST_NO_LAYOUT_V1380=1 \
    -DDAIMOS_TEST_INPLACE_V1382=1 \
    -Dproc_pure_ram_drop_v1377=proc_pure_ram_drop_v1381 \
    -Dproc_pure_ram_restore_v1377=proc_pure_ram_restore_v1381 \
    -Dproc_pure_ram_discard_v1377=proc_pure_ram_discard_v1381 \
    $include -S \
    "$testkit/tests/validation/pure-ram-backing-v1378/test-native-v1378.c" \
    -o "$work/test-native-v1382.s"
{
    printf '.text\n'
    printf '.globl proc_swap_backing_busy\n.globl proc_swap_mount_busy\n'
    printf '.equ PROC_SWAP_BACKING_OFFSET,0406\n'
    printf '.equ PROC_SWAP_MOUNT_SHIFT,022\n'
    printf '.equ PROC_SWAP_TEXT_SHIFT,026\n'
    printf '.equ PROC_SWAP_TEXT_MASK,037777\n'
    sed -n '/^proc_swap_backing_busy:$/,$p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pure_backing_pdp6.s"
} > "$work/pure-backing-guards-v1382.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/guest" --name pure-ram-backing-v1382 \
    --expect __test_exit=0 \
    --examine guard_checks_v1378 --examine free_checks_v1378 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/proc_pure_ram_v1381.s" \
    "$DAIMOS_REPO/system/kernel/mm/mm_pure_rebase_v1381.s" \
    "$DAIMOS_REPO/system/kernel/proc/proc_storage_runtime_v30.s" \
    "$testkit/tests/validation/pure-ram-backing-v1382/invariant-v1382.s" \
    "$work/pure-backing-guards-v1382.s" \
    "$work/test-native-v1382.s"
