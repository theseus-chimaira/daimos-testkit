#!/bin/sh
# v1555: actual production DTFS mount admission on native PDP-6 and
# independent host mkdtfs DTVOL2/DTVOL1 images. No real tape writes.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-v2-ro-v1555.XXXXXX")
if [ "${V1555_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/mkdtfs-v1555" "$DAIMOS_REPO/tools/host/mkdtfs.c"
"$work/mkdtfs-v1555" --durable-v1550 -o "$work/v2clean.tap"
"$work/mkdtfs-v1555" --durable-v1550 -o "$work/v2other.tap"
"$work/mkdtfs-v1555" -o "$work/v1.tap"

python3 - "$DAIMOS_REPO" "$self" "$work" <<'PY'
from pathlib import Path
import sys

repo,self,work=(Path(s) for s in sys.argv[1:])
mask=0o777777777777
dirty=0o552255225522
salt=0o246134572610

def read_block(name,rbn):
    with (work/name).open('rb') as f:
        f.seek(rbn*128*8)
        data=f.read(128*8)
    assert len(data)==1024,(name,rbn)
    values=[]
    for i in range(0,len(data),8):
        hi=int.from_bytes(data[i:i+4],'little')
        lo=int.from_bytes(data[i+4:i+8],'little')
        assert hi <= 0o777777 and lo <= 0o777777
        values.append((hi<<18)|lo)
    return values

clean=read_block('v2clean.tap',0)
other=read_block('v2other.tap',0)
old=read_block('v1.tap',0)
directory=read_block('v2clean.tap',0o144)
assert clean[0]==0o446466575422
assert old[0]==0o446466575421
assert clean[1:3]!=other[1:3]
assert clean[4]==0 and clean[6:]==[0]*122
assert directory[-1]==0o446446632021
dirty_words=clean[:]
dirty_words[4]=dirty
dirty_words[5]=(~(dirty_words[0]^dirty_words[1]^dirty_words[2]^
                  dirty^salt))&mask
records=(('v2_clean',clean),('v2_dirty',dirty_words),
         ('v2_other',other),('v1',old),('dir',directory))
lines=['.data\n']
for name,values in records:
    lines.append('.globl record_%s_v1555\n' % name)
    lines.append('record_%s_v1555:\n' % name)
    lines.extend('        .word 0%012o\n' % word for word in values)
(work/'physical-records-v1555.s').write_text(''.join(lines))

runtime=(repo/'system/kernel/fs/dtfs_runtime.s').read_text()
mount=runtime[runtime.index('dtfs_mount_unit:\n'):
              runtime.index('dtfs_lookup:\n')]
restore=runtime[runtime.index('dtfs_restore4:\n'):
                runtime.index('; Compact vnode predicates.',
                              runtime.index('dtfs_restore4:\n'))]
cache=(repo/'system/kernel/storage/bcache_pdp6.s').read_text()
invalidate=cache[cache.index('bcache_invalidate_all:\n'):
                 cache.index('; void bcache_workspace_invalidate')]
header=('.text\n.set DTFS_ENABLE_TENEX,0\n'
        '.set DTFS_ENABLE_ITS,0\n.set DTFS_ENABLE_FOREIGN,0\n'
        '.globl dtfs_mount_unit\n.globl bcache_invalidate_all\n')
source=header+restore+mount+invalidate
assert source.count('pushj   17,dtfs_intent_validate_v1550')==1
assert source.count('iori    010,0100000')==1
assert source.count('trnn    1,1                     ; VFS_MOUNT_RDONLY')==1

support=(self/'daimos-dtfs-volume-id-native-v1520.s').read_text()
support_head=support[:support.index('main:\n')]
start=support.index('stamp_identity_v1520:\n')
support=support_head+support[start:]
support='.globl roots_v1557\n.globl mounted_media_v1557\n'+support
for name in ('raw_reads_v1519', 'published_v1519', 'patched_v1519',
             'media_dir_v1519', 'media_id_v1519', 'blank_identity_v1520',
             'shape_slabs_v1519', 'extent_slabs_v1519',
             'media_online_v1519', 'identity_unreadable_v1520',
             'returned_root_v1519', 'cache_slab_v1519',
             'try_mount_v1519'):
    assert name+':' in support,name
    support='.globl '+name+'\n'+support
old_flags='movei   3,011                  ; native DTFS, read-only'
assert support.count(old_flags)==1
support=support.replace(old_flags,'move    3,mount_flags_v1555',1)
old_patch='dtfs_patch_media:\n        aos     patched_v1519\n'
assert support.count(old_patch)==1
support=support.replace(old_patch,old_patch+'        movem   2,patched_media_v1555\n',1)
(work/'fixture-support-v1555.s').write_text(support)

mutants=(
    ('skip-v2-same-unit-check',
     'movei   2,1                     ; candidate DTVOL2 mount\n'
     '        pushj   17,dtfs_v2_mount_exclusive_v1557',
     'movei   2,1\n        setz    1, ; bypass V2 physical association'),
    ('skip-v1-on-v2-check',
     'setz    2,                      ; candidate V1 / zero legacy\n'
     '        pushj   17,dtfs_v2_mount_exclusive_v1557',
     'setz    2,\n        setz    1, ; bypass V1->V2 conflict'),
    ('allow-v2-rw',
     'trnn    1,1                     ; VFS_MOUNT_RDONLY explicitly set',
     'trne    1,1                     ; WRONG: deny RO, allow RW'),
    ('skip-v2-seal-parser',
     'pushj   17,dtfs_intent_validate_v1550',
     'setz    1,                     ; WRONG: accept dirty/torn V2'),
    ('allow-v2-dirty',
     'jumpn   1,dtfs_mount_unit_fail ; DIRTY and INVALID both refused',
     'jumpe   1,dtfs_mount_unit_fail ; WRONG: require dirty'),
    ('skip-v2-tag',
     'iori    010,0100000            ; runtime FORMAT_V2 only after read',
     'move    010,010              ; WRONG: do not publish V2 tag'),
    ('ignore-v1-check',
     'pushj   17,dtfs_identity_validate_v1522',
     'setz    1,                       ; WRONG: admit corrupt V1'),
    ('skip-high-id',
     'move    1,-2(17)               ; high half of volume identifier',
     'setz    1,                       ; WRONG: discard high ID'),
    ('skip-low-id',
     'move    1,-1(17)               ; low half',
     'setz    1,                       ; WRONG: discard low ID'),
    ('skip-directory-magic',
     'came    1,[0446446632021]',
     'came    1,1'),
    ('skip-physical-id-read',
     'setz    2,                      ; native identity RBN 0\n'
     '        movei   3,fs_block_workspace\n'
     '        pushj   17,dtfs_dtc_read_jump',
     'setz    2,\n        movei   3,fs_block_workspace\n'
     '        setz    1,                     ; no physical identity I/O'),
)
for name,old,new in mutants:
    assert source.count(old)==1,(name,source.count(old))
    (work/('mutant-'+name+'-v1555.s')).write_text(source.replace(old,new,1))
(work/'native-source-v1555.s').write_text(source)
print('v1557: 24 native genuine-image admission/exclusive-unit cases and '
      '%d source mutations' % len(mutants))
PY

run_native() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 400000 --timeout 20 \
        --workdir "$work/run-$label" --name "dtfs-v2-mount-$label-v1555" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-v2-ro-admission-v1555.s" \
        "$work/fixture-support-v1555.s" \
        "$work/physical-records-v1555.s" \
        "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_validate_v1550.s" \
        "$DAIMOS_REPO/system/kernel/fs/dtfs_v2_mount_exclusive_v1557.s" \
        "$source" > "$work/$label.log" 2>&1
}

if ! run_native baseline "$work/native-source-v1555.s"; then
    tail -70 "$work/baseline.log" >&2
    echo 'FAIL v1555: physical DTVOL2 mount admission' >&2
    exit 1
fi
echo 'PASS v1557: 24 native PDP-6 physical V2 admission/ownership scenarios'

for mutation in skip-v2-same-unit-check skip-v1-on-v2-check \
    allow-v2-rw skip-v2-seal-parser allow-v2-dirty \
    skip-v2-tag ignore-v1-check skip-high-id skip-low-id \
    skip-directory-magic skip-physical-id-read; do
    if run_native "$mutation" "$work/mutant-$mutation-v1555.s"; then
        echo "FAIL v1555: admitted unsafe mount mutation $mutation" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutation.log" || {
        echo "FAIL v1555: mutation failed outside native oracle: $mutation" >&2
        tail -28 "$work/$mutation.log" >&2
        exit 1
    }
    echo "PASS v1555: rejected $mutation"
done
echo 'PASS v1555: production DTVOL2 RO mount admission source accepted'
