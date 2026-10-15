#!/bin/sh
# Compile and assemble the staged userspace encoder; runtime I/O is separate.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:=$HOME/tmp}"
mkdir -p "$TMPDIR/d6codec-userland-v075"
inc="-I$DAIMOS_REPO/userland/libc -I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/storage -I$PDP10_PREFIX/include"
# Intentional word splitting: the include paths cannot contain whitespace.
# shellcheck disable=SC2086
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=gnu99 -Os -march=pdp6 -mcpu=pdp6 -S $inc \
 "$DAIMOS_REPO/userland/d6lz/d6codec_group_v075.c" -o "$TMPDIR/d6codec-userland-v075/code.s"
"$PDP10_PREFIX/bin/das" -F -C -O "$TMPDIR/d6codec-userland-v075/code.dobj" "$TMPDIR/d6codec-userland-v075/code.s"
"$PDP10_PREFIX/bin/pdp10-objdump" -t "$TMPDIR/d6codec-userland-v075/code.dobj" | grep -q d6codec_group_v075_compress_fd
printf 'PASS d6codec-userland-v075 target compile/assemble/symbol\n'
