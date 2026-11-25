#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-lowmem-exec-v1935.XXXXXX")
trap 'echo "v1935 native evidence: $work"' EXIT
python3 - "$DAIMOS_REPO/system/kernel" "$work" <<'PY'
from pathlib import Path
import sys
src,work=map(Path,sys.argv[1:])
s=(src/'proc/proc_pure_backing_pdp6.s').read_text()
res=s[s.index('proc_swap_unpack_backing:'):s.index('/*',s.index('proc_swap_unpack_backing_bad:'))]+s[s.index('; Transient executable backing reservation.'): ]
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
low=(src/'proc/exec_lowmem_pdp6.s').read_text()
vm=(src/'proc/vm_pdp6.s').read_text()
base += '.text\n.globl exec_replace_current_lowmem\n.equ EXEC_LAUNCH_MM_OWNER,013\n.equ MM_TYPE_KERNEL_DYNAMIC,3\n.equ PROC_BRK_OFFSET,0407\n.equ EXEC_LOAD_RT_REQUIRED,1\n'+low[low.index('        ; Frame offsets relative to the fully advanced AC17.'):]+vm[vm.index('vm_user_mapping_hold:'):vm.index('        popj    17,',vm.index('vm_user_mapping_release_done:'))+len('        popj    17,')]
(work/'base.s').write_text(base)
for name,old,new in [
 ('unsafe-live-publish','        camn    10,proc_current_ptr\n        popj    17,\n',''),
 ('unsafe-live-rollback','        came    10,proc_current_ptr\n        hrrzs   0(10)','        hrrzs   0(10)'),
 ('unsafe-entry','        movei   2,020(14)','        setz    2,')]:
    assert loader.count(old)==1,name
    (work/(name+'.s')).write_text(loader.replace(old,new,1))
a='        pushj   17,vm_user_mapping_hold\n        move    1,15'
assert base.count(a)==1
(work/'unsafe-map.s').write_text(base.replace(a,'        move    1,15',1))
PY
includes="-I$DAIMOS_REPO/tools/host"
for d in boot core drivers fs ipc mm modules proc storage; do includes="$includes -I$DAIMOS_REPO/system/kernel/$d"; done
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $includes -S "$DAIMOS_REPO/system/kernel/proc/proc_pure_attach.c" -o "$work/attach.s"
for variant in base unsafe-live-publish unsafe-live-rollback unsafe-entry unsafe-map; do
 leaf="$work/base.s"
 load="$work/load.s"
 case "$variant" in base) ;; unsafe-map) leaf="$work/unsafe-map.s";; *) load="$work/$variant.s";; esac
 if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$work/$variant" --name "pure-lowmem-$variant-v1935" --expect __test_exit=0 "$kit/tests/validation/daimos-test-crt0-v1.s" "$here/test-native-v1935.s" "$leaf" "$load" "$work/attach.s" > "$work/$variant.log" 2>&1; then
  [ "$variant" = base ] || { echo "FAIL: unsafe $variant accepted"; exit 1; }
  cat "$work/$variant.log"
 else
  [ "$variant" != base ] && grep -F 'FAIL: __test_exit' "$work/$variant.log" || { cat "$work/$variant.log"; exit 1; }
  echo "PASS: $variant rejected"
 fi
done
