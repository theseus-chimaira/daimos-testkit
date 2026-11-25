#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-load-reservation-v1933.XXXXXX")
trap 'echo "v1933 native evidence: $work"' EXIT
python3 - "$DAIMOS_REPO/system/kernel" "$work" <<'PY'
from pathlib import Path
import sys
src,work=map(Path,sys.argv[1:])
s=(src/'proc/proc_pure_backing_pdp6.s').read_text()
res=s[s.index('; Transient executable backing reservation.'): ]
s=(src/'fs/fs_mres.s').read_text()
gate=s[s.index('fs_provider_reg_call:'):s.index('; KCORE memory-pressure bridge')]
s=(src/'fs/vfs.s').read_text()
guard=s[s.index('vfs_dtfs_owner_admit_v1562:'):s.index('; v1562: acquire a temporary')]
ro=s[s.index('vfs_readonly:'):s.index('; int vfs_storage_release')]
prefix=''' .text
.globl fs_provider_reg_call
.globl fs_d6fs_service_jump
.globl fs_dtfs_service_jump
.globl fs_tsfs_service_jump
.globl fs_memfs_service_jump
.globl vfs_dtfs_owner_admit_v1562
.globl vfs_readonly
.equ PROC_SWAP_BACKING_OFFSET,0406
.equ PROC_SWAP_MOUNT_SHIFT,022
.equ PROC_SWAP_TEXT_SHIFT,026
.equ PROC_SWAP_TEXT_MASK,037777
'''
base=prefix+res+gate+guard+ro
loader=(src/'proc/exec_load.s').read_text()
(work/'base.s').write_text(base)
(work/'load.s').write_text(loader)
for name,old,new in [
 ('unsafe-before-lease','        jumpn   7,fs_provider_serialized ; index zero: MEMFS never sleeps','        cain    6,032\n        jrst    proc_exec_reserve_v1933\n        jumpn   7,fs_provider_serialized ; index zero: MEMFS never sleeps'),
 ('unsafe-file-scan','        move    2,proc_exec_resv_head_v1933\nproc_exec_node_scan_v1933:', '        setz    2,\nproc_exec_node_scan_v1933:'),
 ('unsafe-mount-scan','        move    2,proc_exec_resv_head_v1933\nproc_exec_mount_scan_v1933:', '        setz    2,\nproc_exec_mount_scan_v1933:'),
 ('unsafe-quiesce','        jumpn   3,proc_exec_reserve_bad_v1933\n',''),
 ('unsafe-release','        movem   3,(2)\n        setzm   1(1)','        setzm   proc_exec_resv_head_v1933\n        setzm   1(1)')]:
    assert base.count(old)==1,name
    (work/(name+'.s')).write_text(base.replace(old,new,1))
old='''        pushj   17,proc_exec_release_v1933
'''
assert loader.count(old)==1
(work/'unsafe-leak-load.s').write_text(loader.replace(old,'',1))
PY
for variant in base unsafe-before-lease unsafe-file-scan unsafe-mount-scan unsafe-quiesce unsafe-release unsafe-leak-load; do
 leaf="$work/$variant.s"
 load="$work/load.s"
 if [ "$variant" = unsafe-leak-load ]; then leaf="$work/base.s"; load="$work/unsafe-leak-load.s"; fi
 if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$work/$variant" --name "pure-load-$variant-v1933" --expect __test_exit=0 "$kit/tests/validation/daimos-test-crt0-v1.s" "$here/test-native-v1933.s" "$leaf" "$load" > "$work/$variant.log" 2>&1; then
  [ "$variant" = base ] || { echo "FAIL: unsafe $variant accepted"; exit 1; }
  cat "$work/$variant.log"
 else
  [ "$variant" != base ] && grep -F 'FAIL: __test_exit' "$work/$variant.log" || { cat "$work/$variant.log"; exit 1; }
  echo "PASS: $variant rejected"
 fi
done
