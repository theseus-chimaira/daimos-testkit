#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"; : "${TESTKIT_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}; export PDP10_PREFIX TMPDIR
out="$TMPDIR/d6codec-packed-mm-v080"; mkdir -p "$out"
inc="-I$DAIMOS_REPO/system/kernel -I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/ipc -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules -I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage -I$PDP10_PREFIX/include"
for name in proc_packed_layout_v36 proc_packed_publish_v44 proc_packed_owner_v37 proc_packed_evict_v077 proc_packed_restore_v46 proc_packed_inline_v079; do
 "$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=gnu99 -Os -march=pdp6 -mcpu=pdp6 $inc -S -o "$out/$name.s" "$DAIMOS_REPO/system/kernel/proc/$name.c"
done
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=gnu99 -Os -march=pdp6 -mcpu=pdp6 $inc -S -o "$out/test-v080.s" "$TESTKIT_REPO/tests/validation/d6codec-packed-mm-v080/test-v080.c"
cat > "$out/stub-v080.s" <<'ASM'
.text
.globl main
.globl __test_exit
.globl vfs_read_words
__start:
 movei 17,stack_v080-1
 hrli 17,-01000
 movei 1,d6i67_image_start
 hrl 1,1
 hrri 1,000060
 blt 1,000206  ; v067 fixed image: 87 decimal = 0127 octal words
 pushj 17,main
 movem 1,__test_exit
 jrst 4,0
vfs_read_words:
 seto 1,
 popj 17,
.bss
__test_exit: .block 1
stack_v080: .block 01000
ASM
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 40 --workdir "$out/run" --name d6codec-packed-mm-v080 --expect __test_exit=0 "$out/stub-v080.s" "$out/test-v080.s" "$out/proc_packed_layout_v36.s" "$out/proc_packed_publish_v44.s" "$out/proc_packed_owner_v37.s" "$out/proc_packed_evict_v077.s" "$out/proc_packed_restore_v46.s" "$out/proc_packed_inline_v079.s" "$DAIMOS_REPO/system/kernel/core/d6codec_inline_fixed_v067.s" "$DAIMOS_REPO/system/kernel/core/d6codec_inline_encode_v078.s" "$DAIMOS_REPO/system/kernel/core/d6codec_kpack_inline_v078.s" "$DAIMOS_REPO/system/kernel/core/d6codec_inline_vfs_v070.s"
