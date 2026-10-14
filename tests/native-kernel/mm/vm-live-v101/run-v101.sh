#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
out="$TMPDIR/mm-vm-live-v101"
mkdir -p "$out"
# Extract unmodified production routines, without linking unrelated
# kernel entry points whose dependencies are not part of this fixture.
awk '/^vm_extent_move:/{printing=1} /^vm_enter_initial_user:/{printing=0} printing' \
 "$DAIMOS_REPO/system/kernel/proc/vm_pdp6.s" > "$out/vm-exact-v101.s"
awk '/^fs_copy_words:/{printing=1} /^        \.globl  fs_zero_words/{printing=0} printing' \
 "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" > "$out/move-exact-v101.s"
sed -i '1i\.globl vm_extent_move' "$out/vm-exact-v101.s"
sed -i '1i\.globl fs_copy_words\n.globl fs_move_words' "$out/move-exact-v101.s"
cat > "$out/entry-v101.s" <<'ASM'
.text
.globl vm_extent_move
.globl fs_copy_words
.globl fs_move_words
.globl kconst_6_6
kconst_6_6: .word 6,,6
ASM
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
 --exec-mode go --start 1000 --timeout 30 --workdir "$out/run" \
 --name mm-vm-live-v101 --expect __test_exit=0 \
 "$(dirname "$0")/../../../validation/d6codec-native-v051/crt_stack_v051.s" \
 "$(dirname "$0")/test-v101.s" \
 "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" \
 "$out/entry-v101.s" "$out/vm-exact-v101.s" "$out/move-exact-v101.s" \
 "$(dirname "$0")/deps-v101.s"
