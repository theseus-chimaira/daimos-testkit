#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
work="$TMPDIR/exec-image-cutover-v1388-native"
mkdir -p "$work"
python3 "$testkit/tests/validation/exec-image-cutover-v1388/make-candidate-v1388.py" \
    "$DAIMOS_REPO/system/kernel/proc/exec_load.s" \
    "$work/exec-load-candidate-v1388.s"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -I"$DAIMOS_REPO/system/kernel/proc" \
    -I"$DAIMOS_REPO/system/kernel/fs" \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/storage" \
    -I"$DAIMOS_REPO/system/kernel/mm" \
    -I"$PDP10_PREFIX/include" \
    -S "$testkit/tests/validation/exec-image-cutover-v1388/test-native-v1388.c" \
    -o "$work/test-native-v1388.s"
{
    printf '.text\n'
    printf '.globl proc_swap_unpack_backing\n'
    printf 'proc_swap_unpack_backing:\n'
    printf '    setz 1,\n'
    printf '    setz 2,\n'
    printf '    popj 17,\n'
} > "$work/backing-unused-v1388.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/guest" --name exec-image-cutover-v1388 \
    --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/exec-load-candidate-v1388.s" \
    "$DAIMOS_REPO/system/kernel/proc/exec_image_common_v1386.s" \
    "$work/backing-unused-v1388.s" \
    "$work/test-native-v1388.s"
