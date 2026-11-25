#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-mutation-lease-v1932.XXXXXX")
trap 'echo "v1932 native evidence: $work"' EXIT
python3 - "$DAIMOS_REPO/system/kernel" "$work" <<'PY'
from pathlib import Path
import sys
src, work=map(Path,sys.argv[1:])
s=(src/'fs/fs_mres.s').read_text()
gateway=s[s.index('fs_provider_reg_call:'):s.index('; KCORE memory-pressure bridge')]
s=(src/'proc/proc_pure_backing_pdp6.s').read_text()
scan=s[s.index('proc_swap_backing_busy:'):s.index('/* Return nonzero while a resident or swapped PURE image owns MOUNT')]
s=(src/'fs/vfs.s').read_text()
ro=s[s.index('vfs_readonly:'):s.index('; int vfs_storage_release')]
s=(src/'fs/d6fs_provider_namespace_pdp6.s').read_text()
unlink=s[s.index('d6fs_provider_unlink:'):s.index('; int d6fs_provider_rename')]
prefix=''' .text
.globl fs_provider_reg_call
.globl fs_d6fs_service_jump
.globl fs_dtfs_service_jump
.globl fs_tsfs_service_jump
.globl fs_memfs_service_jump
.globl proc_swap_backing_busy
.globl vfs_readonly
.globl d6fs_provider_unlink
.equ PROC_SWAP_BACKING_OFFSET,0406
.equ PROC_SWAP_MOUNT_SHIFT,022
.equ PROC_SWAP_TEXT_SHIFT,026
.equ PROC_SWAP_TEXT_MASK,037777
.equ D6FS_FLAG_PROTECTED,022
.equ D6FS_TYPE_DIR,2
.equ D6FS_FCB_RESERVED,015
.equ D6FS_FCB_WORDS,020
'''
base=prefix+gateway+scan+ro+unlink
(work/'base.s').write_text(base)
for name,old,new in [
 ('unsafe-owner','        pushj   17,proc_swap_backing_busy\n        jumpe   1,fs_provider_dispatch_v1932','        jrst    fs_provider_dispatch_v1932'),
 ('unsafe-ro','        pushj   17,vfs_readonly\n        jumpn   1,fs_provider_write_refuse_v1932',''),
 ('unsafe-unlink','        pushj   17,proc_swap_backing_busy\n        jumpn   1,d6fs_unlink_fail',''),
 ('unsafe-child','        hrr     1,013\n        pushj   17,proc_swap_backing_busy','        pushj   17,proc_swap_backing_busy')]:
    assert base.count(old)==1,name
    (work/(name+'.s')).write_text(base.replace(old,new,1))
PY
for variant in base unsafe-owner unsafe-ro unsafe-unlink unsafe-child; do
 if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$work/$variant" --name "pure-mutation-$variant-v1932" --expect __test_exit=0 "$kit/tests/validation/daimos-test-crt0-v1.s" "$here/test-native-v1932.s" "$work/$variant.s" > "$work/$variant.log" 2>&1; then
  [ "$variant" = base ] || { echo "FAIL: unsafe $variant accepted"; exit 1; }
  cat "$work/$variant.log"
 else
  [ "$variant" != base ] && grep -F 'FAIL: __test_exit' "$work/$variant.log" || { cat "$work/$variant.log"; exit 1; }
  echo "PASS: $variant rejected"
 fi
done
