#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}; export TMPDIR PDP10_PREFIX
out="$TMPDIR/d6codec-swap-dispatch-v083"; mkdir -p "$out"
inc="-I$DAIMOS_REPO/system/kernel -I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/ipc -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules -I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage -I$PDP10_PREFIX/include"
for unit in "$DAIMOS_REPO/system/kernel/proc/proc_storage_map_v28.c" "$DAIMOS_REPO/system/kernel/proc/proc_swap_dispatch_v083.c" "$(dirname "$0")/test-v083.c"; do
 name=$(basename "$unit" .c)
 "$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=gnu99 -Os -march=pdp6 -mcpu=pdp6 $inc -S -o "$out/$name.s" "$unit"
done
cat > "$out/entry-v083.s" <<'ASM'
.text
.globl main
.globl __test_exit
__start:
 movei 17,stack_v083-1
 hrli 17,-01000
 pushj 17,main
 movem 1,__test_exit
 jrst 4,0
.bss
__test_exit: .block 1
stack_v083: .block 01000
ASM
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$out/run" --name d6codec-swap-dispatch-v083 --expect __test_exit=0 "$out/entry-v083.s" "$out/test-v083.s" "$out/proc_swap_dispatch_v083.s" "$out/proc_storage_map_v28.s"
# Verify the alternate scheduler calls the exact dispatcher, without
# attempting a standalone link of its many production kernel dependencies.
grep -q 'pushj   17,proc_swap_restore_dispatch_v083' \
    "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6_inline_v083.s"
