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
parts=[s[s.index('d6fs_reader_get_block:'):s.index('        .globl  d6fs_reader_fcb')],s[s.index('d6fs_restore3:'):s.index('        .globl  d6fs_reader_write_block')],s[s.index('d6fs_mres_dispatch:'):s.index('d6fs_provider_space:')],s[s.index('d6fs_mount_validated:'):s.index('d6fs_mres_create:')],s[s.index('d6fs_provider_prepare_unmount:'):s.index('        .globl  wall_time36',s.index('d6fs_provider_prepare_unmount:'))]]
b=(src/'storage/fs_backing.s').read_text()
parts.append(b[b.index('fs_backing_read:'):b.index('; Root-storage bridge')])
b=(src/'storage/bcache_pdp6.s').read_text()
parts.append(b[b.index('bcache_invalidate_all:'):b.index('        .bss',b.index('bcache_invalidate_all:'))])
base='.text\n.globl d6fs_reader_get_block\n.globl d6fs_reader_commit_cache\n.globl fs_backing_write\n.globl d6fs_mres_dispatch\n.globl d6fs_provider_prepare_unmount\n.globl fs_backing_read\n.globl bcache_invalidate_all\n'+''.join(parts)
gate=(src/'proc/proc_storage_runtime_v30.s').read_text()
base += gate[gate.index('kcore_root_fs_io_failure_v1538:'):]
(work/'base.s').write_text(base)
for name,old,new in [('unsafe-uuid-high','        came    2,(4)\n        jrst    d6fs_pure_media_bad_v1927\n',''),('unsafe-uuid-low','        came    3,(4)\n        jrst    d6fs_pure_media_bad_v1927\n',''),('unsafe-header-clear','        setzm   fs_block_workspace\n        move    4,[fs_block_workspace,,fs_block_workspace+1]\n        blt     4,fs_block_workspace+017\n',''),('unsafe-cache','        pushj   17,bcache_invalidate_all\n',''),('unsafe-read-note','        movei   2,1                     ; READ_SUSPECT\n        pushj   17,d6fs_note_failure_v1929\n',''),('unsafe-write-note','        movei   2,2                     ; WRITE_UNCERTAIN\n        pushj   17,d6fs_note_failure_v1929\n',''),('unsafe-reader','        came    1,(4)\n        jrst    d6fs_note_done_v1929\n',''),('unsafe-write-proof','        trne    6,2\n        jrst    d6fs_pure_media_bad_v1927\n',''),('unsafe-private-tag','        camn    5,6\n        setom   (4)\n',''),('unsafe-other-tag','        camn    5,6\n        setom   (4)\n','        setom   (4)\n')]:
    assert base.count(old)==1,name
    (work/(name+'.s')).write_text(base.replace(old,new,1))
PY
for variant in base unsafe-uuid-high unsafe-uuid-low unsafe-header-clear unsafe-cache unsafe-read-note unsafe-write-note unsafe-reader unsafe-write-proof unsafe-private-tag unsafe-other-tag; do
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$work/$variant" --name "pure-d6fs-media-$variant-v1927" --expect __test_exit=0 "$kit/tests/validation/daimos-test-crt0-v1.s" "$here/test-native-v1927.s" "$work/$variant.s" > "$work/$variant.log" 2>&1; then
        [ "$variant" = base ] || { echo "FAIL: $variant accepted"; exit 1; }
        cat "$work/$variant.log"
    else
        [ "$variant" != base ] && grep -F 'FAIL: __test_exit' "$work/$variant.log" || { cat "$work/$variant.log"; exit 1; }
        echo "PASS: $variant rejected"
    fi
done
