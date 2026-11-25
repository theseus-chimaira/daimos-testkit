#!/bin/sh
# Source-linked PDP-6 native acceptance of ONE FULL/PURE image engine.
# Disk swap is unchanged: the FULL reload is tested as a candidate only.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
KCC_BIN_V1392=${KCC_BIN_V1392:-$PDP10_PREFIX/bin/kcc}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-dtfs-media-v1925.XXXXXX")
trap 'echo "v1925 evidence: $work"' EXIT
include="-I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/storage -I$DAIMOS_REPO/system/kernel/modules -I$DAIMOS_REPO/system/kernel/drivers -I$PDP10_PREFIX/include -I$testkit/tests/validation/pure-ram-lifecycle-v1377 -I$testkit/tests/validation/pure-ram-registryfree-v1379 -I$testkit/tests/validation/pure-ram-inplace-v1381"
for src in proc_pure_ram_v1381 proc_pure_restore_v1384 proc_pure_ram_restore_v1391; do
    case "$src" in
        proc_pure_ram_v1381) flag=DAIMOS_SWAPLESS_PURE_RAM_V1381 ;;
        proc_pure_restore_v1384) flag=DAIMOS_SWAPLESS_PREFIX_V1384 ;;
        *) flag=DAIMOS_PURE_FULL_V1391 ;;
    esac
    "$KCC_BIN_V1392" -Pgnu99 -O -x=pdp6 -m=gas \
        -D"$flag"=1 $include \
        -S "$DAIMOS_REPO/system/kernel/proc/$src.c" \
        -o "$work/$src.s"
done
{
    cat "$testkit/tests/validation/pure-ram-prefix-v1384/test-native-v1384.c"
    cat "$(dirname "$0")/test-bridge-v1925.c"
} > "$work/test.c"
"$KCC_BIN_V1392" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_TEST_PLAIN_DXR_V1385=1 -DDAIMOS_TEST_SHARED_IMAGE_V1387=1 \
    -DDAIMOS_TEST_SHARED_FULL_V1390=1 -DDAIMOS_TEST_PURE_ROLLBACK_V1395=1 \
    -DDAIMOS_TEST_BACKING_IDENTITY_V1923=1 $include \
    -S "$work/test.c" -o "$work/test-native-v1390.s"

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
# This historical fixture provides the controlled four-register decoder
# under its former symbol. The v1464 production codec cutover renamed
# the entry point; preserve the tested ABI with a TEST-ONLY alias,
# as in the already accepted v1487 native DXR suite.
cat > "$work/codec-alias-v1608.s" <<'ASM'
        .text
        .globl d6codec_decode_vfs_v1458
        .globl d6lz36_decode_vfs
d6codec_decode_vfs_v1458:
        jrst    d6lz36_decode_vfs
ASM
run_guest() {
    name=$1
    image=$2
    unpack=$3
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/$name" --name "$name" \
    --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$(dirname "$0")/provider-bridge-v1925.s" \
    "$image" \
    "$work/proc_pure_ram_v1381.s" \
    "$work/proc_pure_restore_v1384.s" \
    "$work/proc_pure_ram_restore_v1391.s" \
    "$DAIMOS_REPO/system/kernel/mm/mm_pure_rebase_v1381.s" \
    "$DAIMOS_REPO/system/kernel/mm/mm_pure_expand_v1384.s" \
    "$DAIMOS_REPO/system/kernel/proc/proc_storage_runtime_v30.s" \
    "$DAIMOS_REPO/system/kernel/drivers/device_state.s" \
    "$unpack" \
    "$work/codec-alias-v1608.s" \
    "$work/test-native-v1390.s"

}
run_guest pure-dtfs-media-v1925 "$DAIMOS_REPO/system/kernel/proc/exec_image_common_v1386.s" "$work/unpack-backing-v1390.s"
python3 - "$DAIMOS_REPO/system/kernel/proc/exec_image_common_v1386.s" "$work" <<'PY'
from pathlib import Path
import sys
p, work = map(Path, sys.argv[1:])
s = p.read_text()
for name, old in [('skip-first','        pushj   17,ei_bridge_media_v1925\n        jumpn   1,ei_bridge_bad_v1386\n'),('skip-last','        pushj   17,ei_bridge_media_v1925\n        jumpn   1,ei_bridge_return_v1386\n')]:
    assert s.count(old)==1
    (work/(name+'.s')).write_text(s.replace(old,'',1))
PY
for variant in skip-first skip-last; do
    if run_guest "$variant" "$work/$variant.s" "$work/unpack-backing-v1390.s" > "$work/$variant.log" 2>&1; then
        echo "FAIL: $variant accepted"; exit 1
    fi
    grep -F 'FAIL: __test_exit' "$work/$variant.log" || { cat "$work/$variant.log"; exit 1; }
    echo "PASS: unsafe $variant rejected"
done
