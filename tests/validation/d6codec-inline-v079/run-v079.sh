#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${TESTKIT_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
out="$TMPDIR/d6codec-inline-v079-native"
mkdir -p "$out"
inc="-I$DAIMOS_REPO/system/kernel -I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/ipc -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules -I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage -I$PDP10_PREFIX/include"
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=gnu99 -Os -march=pdp6 -mcpu=pdp6 $inc -S -o "$out/wrapper-v079.s" "$DAIMOS_REPO/system/kernel/proc/proc_packed_inline_v079.c"
cat "$TESTKIT_REPO/tests/validation/d6codec-inline-v079/test-v079.s" \
    "$DAIMOS_REPO/system/kernel/core/d6codec_inline_fixed_v067.s" \
    "$DAIMOS_REPO/system/kernel/core/d6codec_inline_encode_v078.s" \
    "$DAIMOS_REPO/system/kernel/core/d6codec_kpack_inline_v078.s" \
    "$DAIMOS_REPO/system/kernel/core/d6codec_inline_vfs_v070.s" \
    "$out/wrapper-v079.s" > "$out/combined-v079.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
    --start 1000 --timeout 30 --workdir "$out/run" \
    --name d6codec-inline-v079 --expect __test_exit=0 \
    "$TESTKIT_REPO/tests/validation/d6codec-native-v051/crt_stack_v051.s" \
    "$out/combined-v079.s"
