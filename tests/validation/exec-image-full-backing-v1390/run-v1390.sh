#!/bin/sh
# Source-linked PDP-6 native acceptance of ONE FULL/PURE image engine.
# Disk swap is unchanged: the FULL reload is tested as a candidate only.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
work="$TMPDIR/exec-image-full-backing-v1390-native"
mkdir -p "$work"
include="-I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/storage -I$DAIMOS_REPO/system/kernel/modules -I$DAIMOS_REPO/system/kernel/drivers -I$PDP10_PREFIX/include -I$testkit/tests/validation/pure-ram-lifecycle-v1377 -I$testkit/tests/validation/pure-ram-registryfree-v1379 -I$testkit/tests/validation/pure-ram-inplace-v1381"
for src in proc_pure_ram_v1381 proc_pure_restore_v1384; do
    case "$src" in
        proc_pure_ram_v1381) flag=DAIMOS_SWAPLESS_PURE_RAM_V1381 ;;
        *) flag=DAIMOS_SWAPLESS_PREFIX_V1384 ;;
    esac
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -D"$flag"=1 $include \
        -S "$DAIMOS_REPO/system/kernel/proc/$src.c" \
        -o "$work/$src.s"
done
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_TEST_PLAIN_DXR_V1385=1 \
    -DDAIMOS_TEST_SHARED_IMAGE_V1387=1 \
    -DDAIMOS_TEST_SHARED_FULL_V1390=1 $include \
    -S "$testkit/tests/validation/pure-ram-prefix-v1384/test-native-v1384.c" \
    -o "$work/test-native-v1390.s"
{
    printf '.text\n'
    printf '.globl proc_swap_unpack_backing\n'
    printf '.equ PROC_SWAP_TEXT_SHIFT,026\n'
    printf '.equ PROC_SWAP_TEXT_MASK,037777\n'
    printf '.equ PROC_SWAP_MOUNT_SHIFT,022\n'
    sed -n '/^proc_swap_unpack_backing:$/,/^proc_swap_reload_pure:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pure_backing_pdp6.s" |
        sed '$d'
} > "$work/unpack-backing-v1390.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/guest" --name exec-image-full-backing-v1390 \
    --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$DAIMOS_REPO/system/kernel/proc/exec_image_common_v1386.s" \
    "$work/proc_pure_ram_v1381.s" \
    "$work/proc_pure_restore_v1384.s" \
    "$DAIMOS_REPO/system/kernel/mm/mm_pure_rebase_v1381.s" \
    "$DAIMOS_REPO/system/kernel/mm/mm_pure_expand_v1384.s" \
    "$DAIMOS_REPO/system/kernel/proc/proc_storage_runtime_v30.s" \
    "$work/unpack-backing-v1390.s" \
    "$work/test-native-v1390.s"
