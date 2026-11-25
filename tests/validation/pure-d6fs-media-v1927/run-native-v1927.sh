#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-d6fs-media-v1927.XXXXXX")
trap 'echo "v1927 native evidence: $work"' EXIT
python3 - "$DAIMOS_REPO/system/kernel" "$work" <<'PY'
from pathlib import Path
import sys
src,work=map(Path,sys.argv[1:])
s=(src/'fs/d6fs_runtime.s').read_text()
parts=[s[s.index('d6fs_reader_get_block:'):s.index('        .globl  d6fs_reader_fcb')],s[s.index('d6fs_restore3:'):s.index('        .globl  d6fs_reader_write_block')],s[s.index('d6fs_mres_dispatch:'):s.index('d6fs_provider_space:')],s[s.index('d6fs_mount_validated:'):s.index('d6fs_mres_create:')],s[s.index('d6fs_provider_toggle_state:'):s.index('        .globl  wall_time36',s.index('d6fs_provider_prepare_unmount:'))]]
b=(src/'storage/fs_backing.s').read_text()
parts.append(b[b.index('fs_backing_read:'):b.index('; Root-storage bridge')])
b=(src/'storage/bcache_pdp6.s').read_text()
parts.append('.equ BCACHE_MM_OWNER,6\n'+b[b.index('bcache_reclaim:'):b.index('        .bss',b.index('bcache_invalidate_all:'))])
base='.text\n.globl d6fs_reader_get_block\n.globl d6fs_reader_commit_cache\n.globl fs_backing_write\n.globl d6fs_mres_dispatch\n.globl d6fs_provider_prepare_unmount\n.globl fs_backing_read\n.globl bcache_invalidate_all\n'+''.join(parts)
gate=(src/'proc/proc_storage_runtime_v30.s').read_text()
base += gate[gate.index('kcore_root_fs_io_failure_v1538:'):]
vfs=(src/'fs/vfs.s').read_text()
base += '\n.globl vfs_unmount\n.globl vfs_dtfs_owner_admit_v1562\n' + vfs[vfs.index('vfs_unmount:\n'):vfs.index('        .data\n; KINIT publishes both bases')]
base += '\n.globl vfs_dtfs_discard_slot_v1531\n'
(work/'base.s').write_text(base)
for name,old,new in [('unsafe-uuid-high','        came    2,(4)\n        jrst    d6fs_pure_media_bad_v1927\n',''),('unsafe-uuid-low','        came    3,(4)\n        jrst    d6fs_pure_media_bad_v1927\n',''),('unsafe-header-clear','        setzm   fs_block_workspace\n        move    4,[fs_block_workspace,,fs_block_workspace+1]\n        blt     4,fs_block_workspace+0177\n',''),('unsafe-cache','        move    010,1\n        pushj   17,bcache_invalidate_all\n        ; Poison the complete header','        move    010,1\n        ; Poison the complete header'),('unsafe-read-note','        movei   2,1                     ; READ_SUSPECT\n        pushj   17,d6fs_note_failure_v1929\n',''),('unsafe-write-note','        movei   2,2                     ; WRITE_UNCERTAIN\n        pushj   17,d6fs_note_failure_v1929\n',''),('unsafe-reader','        came    1,(4)\n        jrst    d6fs_note_done_v1929\n',''),('unsafe-write-proof','        caile   6,1\n        jrst    d6fs_pure_media_bad_v1927\n        jumpl   6,d6fs_pure_media_bad_v1927\n',''),('unsafe-private-tag','        camn    5,6\n        setom   (4)\n',''),('unsafe-other-tag','        camn    5,6\n        setom   (4)\n','        setom   (4)\n'),('unsafe-no-retry','        pushj   17,d6fs_pure_media_v1927\n        jumpn   1,d6fs_dispatch_fail_v1930\n','        setz    1,\n'),('unsafe-poison-dispatch','        caie    7,1                     ; only READ_SUSPECT is recoverable\n        jrst    kret_neg1\n','        jrst    d6fs_dispatch_ready_v1930\n'),('unsafe-lost-arguments','        blt     7,6\n',''),('unsafe-unmount-owner','        pushj   17,vfs_unmount_owner_check_v1523\n        jumpn   1,kret_neg1\n',''),('unsafe-unmount-admit','        trne    2,0020000','        trnn    2,0020000'),('unsafe-unmount-early-clear','        ; VFS clears the barrier only after the root is unpublished.\n','        move    5,dtfs_media_base\n        add     5,4\n        setzm   (5)\n'),('unsafe-unmount-no-proof','d6fs_dispatch_unmount_v1931:\n        caie    6,020\n        jrst    kret_neg1\n','d6fs_dispatch_unmount_v1931:\n        caie    6,020\n        jrst    kret_neg1\n        jrst    d6fs_dispatch_ready_v1930\n')]:
    assert base.count(old)==1,name
    (work/(name+'.s')).write_text(base.replace(old,new,1))
for name,old,new in [
 ('unsafe-admin-cache','        pushj   17,bcache_reclaim        ; source id may be reused after unmount',''),
 ('unsafe-admin-barrier','        iorm    3,(2)\n        move    1,(17)\n        movei   6,033','        move    1,(17)\n        movei   6,033'),
 ('unsafe-admin-poison','        caie    4,2\n        cain    4,3\n        jrst    vfs_poison_slabs_v1939\n        jrst    kret_neg1','        jrst    vfs_poison_slabs_v1939'),
 ('unsafe-admin-root','        came    2,6\n        jrst    kret_neg1\n        move    5,d6fs_active_reader','        move    5,d6fs_active_reader'),
 ('unsafe-admin-reader','        came    3,4\n        jrst    kret_neg1\n        jrst    d6fs_provider_unmount_done','        jrst    d6fs_provider_unmount_done'),
 ('unsafe-admin-no-barrier','d6fs_discard_v1939:\n        trnn    7,0020000\n        jrst    kret_neg1','d6fs_discard_v1939:'),
 ('unsafe-admin-borrow','vfs_d6fs_discard_v1939:\n        trne    3,0020000               ; do not borrow another barrier\n        jrst    vfs_dtfs_discard_bad_v1531','vfs_d6fs_discard_v1939:')]:
    assert base.count(old)==1,name
    (work/(name+'.s')).write_text(base.replace(old,new,1))

PY
for variant in base unsafe-uuid-high unsafe-uuid-low unsafe-header-clear unsafe-cache unsafe-read-note unsafe-write-note unsafe-reader unsafe-write-proof unsafe-private-tag unsafe-other-tag unsafe-no-retry unsafe-poison-dispatch unsafe-lost-arguments unsafe-unmount-owner unsafe-unmount-admit unsafe-unmount-early-clear unsafe-unmount-no-proof unsafe-admin-barrier unsafe-admin-poison unsafe-admin-root unsafe-admin-reader unsafe-admin-no-barrier unsafe-admin-borrow unsafe-admin-cache; do
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$work/$variant" --name "pure-d6fs-media-$variant-v1927" --expect __test_exit=0 "$kit/tests/validation/daimos-test-crt0-v1.s" "$here/test-native-v1927.s" "$work/$variant.s" > "$work/$variant.log" 2>&1; then
        [ "$variant" = base ] || { echo "FAIL: $variant accepted"; exit 1; }
        cat "$work/$variant.log"
    else
        [ "$variant" != base ] && grep -F 'FAIL: __test_exit' "$work/$variant.log" || { cat "$work/$variant.log"; exit 1; }
        echo "PASS: $variant rejected"
    fi
done
