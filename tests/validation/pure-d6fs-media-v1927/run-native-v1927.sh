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
parts=[s[s.index('d6fs_mres_dispatch:'):s.index('d6fs_provider_space:')],s[s.index('d6fs_mount_validated:'):s.index('d6fs_mres_create:')],s[s.index('d6fs_provider_prepare_unmount:'):s.index('        .globl  wall_time36',s.index('d6fs_provider_prepare_unmount:'))]]
b=(src/'storage/fs_backing.s').read_text()
parts.append(b[b.index('fs_backing_read:'):b.index('; int fs_backing_write')])
b=(src/'storage/bcache_pdp6.s').read_text()
parts.append(b[b.index('bcache_invalidate_all:'):b.index('; void bcache_workspace_invalidate',b.index('bcache_invalidate_all:'))])
base='.text\n.globl d6fs_mres_dispatch\n.globl d6fs_provider_prepare_unmount\n.globl fs_backing_read\n.globl bcache_invalidate_all\n'+''.join(parts)
(work/'base.s').write_text(base)
for name,old,new in [('unsafe-uuid-high','        came    2,(4)\n        jrst    d6fs_pure_media_bad_v1927\n',''),('unsafe-uuid-low','        came    3,(4)\n        jrst    d6fs_pure_media_bad_v1927\n',''),('unsafe-header-clear','        setzm   fs_block_workspace\n        move    4,[fs_block_workspace,,fs_block_workspace+1]\n        blt     4,fs_block_workspace+017\n',''),('unsafe-cache','        pushj   17,bcache_invalidate_all\n','')]:
    assert base.count(old)==1,name
    (work/(name+'.s')).write_text(base.replace(old,new,1))
PY
for variant in base unsafe-uuid-high unsafe-uuid-low unsafe-header-clear unsafe-cache; do
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$work/$variant" --name "pure-d6fs-media-$variant-v1927" --expect __test_exit=0 "$kit/tests/validation/daimos-test-crt0-v1.s" "$here/test-native-v1927.s" "$work/$variant.s" > "$work/$variant.log" 2>&1; then
        [ "$variant" = base ] || { echo "FAIL: $variant accepted"; exit 1; }
        cat "$work/$variant.log"
    else
        [ "$variant" != base ] && grep -F 'FAIL: __test_exit' "$work/$variant.log" || { cat "$work/$variant.log"; exit 1; }
        echo "PASS: $variant rejected"
    fi
done
