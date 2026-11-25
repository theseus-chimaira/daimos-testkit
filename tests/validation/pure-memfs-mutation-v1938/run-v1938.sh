#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
fixture="$here/../../target/daimos-memfs-pdp6-v1"
kernel="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/pure-memfs-mutation-v1938.XXXXXX")
trap 'echo "v1938 native evidence: $work"' EXIT
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=c99 -Os -I"$PDP10_PREFIX/include" -I"$kernel/fs" -I"$kernel/mm" -I"$kernel/storage" -I"$kernel/core" -S "$here/test-v1938.c" -o "$work/test.s"
python3 - "$kernel" "$work" <<'PY'
from pathlib import Path
import sys
k,w=map(Path,sys.argv[1:])
s=(k/'proc/proc_pure_backing_pdp6.s').read_text()
(w/'scan.s').write_text('.text\n.globl proc_swap_backing_busy\n.globl proc_swap_mount_busy\n.equ PROC_SWAP_BACKING_OFFSET,0406\n.equ PROC_SWAP_MOUNT_SHIFT,022\n.equ PROC_SWAP_TEXT_SHIFT,026\n.equ PROC_SWAP_TEXT_MASK,037777\n'+s[s.index('proc_swap_backing_busy:'):])
s=(k/'proc/vm_pdp6.s').read_text()
(w/'vm.s').write_text('.text\n.globl vm_space_destroy\n.globl vm_space_startup\n'+s[s.index('vm_space_destroy:'):s.index('vm_space_load_file:')]+s[s.index('vm_space_startup:'):s.index('vm_extent_move:')])
s=(k/'fs/memfs_runtime.s').read_text()
(w/'base.s').write_text(s)
for name,old,new in [
 ('unsafe-write','memfs_write_words:\n        pushj   17,memfs_owner_guard_v1938\n        jumpn   0,kret_neg1','memfs_write_words:'),
 ('unsafe-truncate','memfs_truncate_words:\n        pushj   17,memfs_owner_guard_v1938\n        jumpn   0,kret_neg1','memfs_truncate_words:'),
 ('unsafe-unlink','        pushj   17,memfs_owner_guard_v1938\n        jumpn   0,memfs_restore4_fail',''),
 ('unsafe-unmount','        pushj   17,proc_swap_mount_busy\n        jumpn   1,memfs_mres_unmount_pinned',''),
 ('unsafe-alias','        hrr     1,-1(17)','        move    1,-1(17)')]:
    assert s.count(old)==1,name
    (w/(name+'.s')).write_text(s.replace(old,new,1))
PY
for variant in base unsafe-write unsafe-truncate unsafe-unlink unsafe-unmount unsafe-alias; do
 if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --timeout 30 --workdir "$work/$variant" --name "pure-memfs-$variant-v1938" --expect daimos_memfs_pdp6_result=0 "$fixture/start.s" "$work/test.s" "$kernel/fs/memfs_data_pdp6.s" "$work/$variant.s" "$fixture/fs-helpers.s" "$work/vm.s" "$work/scan.s" "$kernel/core/ret.s" > "$work/$variant.log" 2>&1; then
  [ "$variant" = base ] || { echo "FAIL: unsafe $variant accepted"; exit 1; }
  cat "$work/$variant.log"
 else
  [ "$variant" != base ] && grep -F 'FAIL: daimos_memfs_pdp6_result' "$work/$variant.log" || { cat "$work/$variant.log"; exit 1; }
  echo "PASS: $variant rejected"
 fi
done
