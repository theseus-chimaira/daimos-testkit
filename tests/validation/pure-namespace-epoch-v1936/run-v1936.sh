#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-namespace-epoch-v1936.XXXXXX")
trap 'echo "v1936 native evidence: $work"' EXIT
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
mount=s[s.index('vfs_mount_publish_slot:'):s.index('; int vfs_remount(node)')]
retire=s[s.index('vfs_mount_retire_slot:'):s.index('vfs_unmount_fail:')]
base=prefix+res+gate+guard+ro+'\n.globl vfs_mount_publish_slot\n.globl vfs_mount_retire_slot\n'+mount+retire
loader=(src/'proc/exec_load.s').read_text()
(work/'base.s').write_text(base)
(work/'load.s').write_text(loader)
for name,old,new in [
 ('unsafe-no-epoch','        move    0,fs_namespace_epoch_v1936\n        came    0,-011(17)\n        jrst    exec_load_fail\n',''),
 ('unsafe-mount-publish','vfs_mount_publish_slot:\n        aosn    fs_namespace_epoch_v1936\n        setom   fs_namespace_epoch_v1936','vfs_mount_publish_slot:'),
 ('unsafe-mount-retire','vfs_mount_retire_slot:\n        aosn    fs_namespace_epoch_v1936\n        setom   fs_namespace_epoch_v1936','vfs_mount_retire_slot:'),
 ('unsafe-wrap','        aosn    fs_namespace_epoch_v1936\n        setom   fs_namespace_epoch_v1936','        aos     fs_namespace_epoch_v1936'),
 ('unsafe-no-completion','        pushj   17,@fs_memfs_service_jump(7)\n        aosn    fs_namespace_epoch_v1936\n        setom   fs_namespace_epoch_v1936','        pushj   17,@fs_memfs_service_jump(7)')]:
    target=loader if name=='unsafe-no-epoch' else base
    assert target.count(old)>=1,name
    (work/(name+'.s')).write_text(target.replace(old,new))

PY
for variant in base unsafe-no-epoch unsafe-wrap unsafe-no-completion unsafe-mount-publish unsafe-mount-retire; do
 leaf="$work/$variant.s"
 load="$work/load.s"
 if [ "$variant" = unsafe-no-epoch ]; then leaf="$work/base.s"; load="$work/unsafe-no-epoch.s"; fi
 if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$work/$variant" --name "pure-namespace-$variant-v1936" --expect __test_exit=0 "$kit/tests/validation/daimos-test-crt0-v1.s" "$here/test-native-v1936.s" "$leaf" "$load" > "$work/$variant.log" 2>&1; then
  [ "$variant" = base ] || { echo "FAIL: unsafe $variant accepted"; exit 1; }
  cat "$work/$variant.log"
 else
  [ "$variant" != base ] && grep -F 'FAIL: __test_exit' "$work/$variant.log" || { cat "$work/$variant.log"; exit 1; }
  echo "PASS: $variant rejected"
 fi
done
