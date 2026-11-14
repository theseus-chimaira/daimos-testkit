#!/bin/sh
# Source-linked native PDP-6 recovery of mounted V2/CLEAN after a read fault.
# Original C89 host mkdtfs physical images supply all admitted volume IDs.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-v2-revalidate-v1556.XXXXXX")
if [ "${V1556_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/mkdtfs-v1556" "$DAIMOS_REPO/tools/host/mkdtfs.c"
"$work/mkdtfs-v1556" --durable-v1550 -o "$work/v2original.tap"
"$work/mkdtfs-v1556" --durable-v1550 -o "$work/v2replacement.tap"
"$work/mkdtfs-v1556" -o "$work/v1original.tap"

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo,work=(Path(s) for s in sys.argv[1:])
mask=0o777777777777
salt=0o246134572610
v2magic=0o446466575422
v1magic=0o446466575421

def record(file):
    data=(work/file).read_bytes()[:1024]
    assert len(data)==1024
    result=[]
    for i in range(0,1024,8):
        high=int.from_bytes(data[i:i+4],'little')
        low=int.from_bytes(data[i+4:i+8],'little')
        assert high<=0o777777 and low<=0o777777
        result.append(high<<18|low)
    return result

clean=record('v2original.tap')
other=record('v2replacement.tap')
v1=record('v1original.tap')
assert clean[0]==v2magic and clean[4]==0
assert other[0]==v2magic and clean[1:3]!=other[1:3]
assert v1[0]==v1magic

def seal(words):
    words[3]=(~(words[0]^words[1]^words[2]))&mask
    words[5]=(~(words[0]^words[1]^words[2]^words[4]^salt))&mask
    return words

dirty=clean[:]
dirty[4]=0o552255225522
seal(dirty)
torn=clean[:]
torn[5]^=1
padding=clean[:]
padding[64]=1
unknown=clean[:]
unknown[4]=1
seal(unknown)
zero_high=clean[:]
zero_high[1]=0
seal(zero_high)
zero_low=clean[:]
zero_low[2]=0
seal(zero_low)
badmagic=clean[:]
badmagic[0]=v2magic+1
seal(badmagic)
records={
    'v2_clean':clean, 'v2_other':other, 'v1':v1,
    'v2_dirty':dirty, 'v2_torn':torn, 'v2_padding':padding,
    'v2_unknown':unknown,'v2_zero_hi':zero_high,'v2_zero_lo':zero_low,
    'v2_badmagic':badmagic,'zero':[0]*128,
}
v2s=0o300003                  # V2 + READ_SUSPECT + DTC3
v2ok=0o100003
v1s=0o200003
root=0o050101000000
foreign=0o060101000000
other_mount=0o050201000000
owner=(0o12345<<18)

# physical record, admitted-identity source, initial media, root,
# VFS readonly bitmap, raw mode, return, final media, reads, cache invalid.
cases=[
    ('recovered original V2', 'v2_clean','v2_clean',v2s,root,1,0,0,v2ok,1,1),
    ('preserve UID/GID owner18', 'v2_clean','v2_clean',v2s|owner,root,1,0,0,v2ok|owner,1,1),
    ('no fault does not issue physical I/O', 'v2_clean','v2_clean',v2ok,root,1,0,0,v2ok,0,0),
    ('dirty is never recovered', 'v2_dirty','v2_clean',v2s,root,1,0,-1,v2s,1,1),
    ('replacement different volume ID', 'v2_other','v2_clean',v2s,root,1,0,-1,v2s,1,1),
    ('V1 never downgrades V2', 'v1','v2_clean',v2s,root,1,0,-1,v2s,1,1),
    ('zero legacy never downgrades V2', 'zero','v2_clean',v2s,root,1,0,-1,v2s,1,1),
    ('torn seal', 'v2_torn','v2_clean',v2s,root,1,0,-1,v2s,1,1),
    ('bad zero padding', 'v2_padding','v2_clean',v2s,root,1,0,-1,v2s,1,1),
    ('unknown but checked state', 'v2_unknown','v2_clean',v2s,root,1,0,-1,v2s,1,1),
    ('zero high ID with repaired checks', 'v2_zero_hi','v2_clean',v2s,root,1,0,-1,v2s,1,1),
    ('zero low ID with repaired checks', 'v2_zero_lo','v2_clean',v2s,root,1,0,-1,v2s,1,1),
    ('wrong magic with repaired checks', 'v2_badmagic','v2_clean',v2s,root,1,0,-1,v2s,1,1),
    ('raw physical read error', 'v2_clean','v2_clean',v2s,root,1,1,-1,v2s,1,1),
    ('short transfer false success', 'v2_clean','v2_clean',v2s,root,1,2,-1,v2s,1,1),
    ('no bytes false success', 'v2_clean','v2_clean',v2s,root,1,3,-1,v2s,1,1),
    ('mid-read WRITE_UNCERTAIN', 'v2_clean','v2_clean',v2s,root,1,4,-1,v2s|0o400000,1,1),
    ('mid-read high ID change', 'v2_clean','v2_clean',v2s,root,1,5,-1,v2s,1,1),
    ('mid-read low ID change', 'v2_clean','v2_clean',v2s,root,1,6,-1,v2s,1,1),
    ('mid-read RW promotion', 'v2_clean','v2_clean',v2s,root,1,7,-1,v2s,1,1),
    ('mid-read wrong provider', 'v2_clean','v2_clean',v2s,root,1,8,-1,v2s,1,1),
    ('mid-read changed mount ID', 'v2_clean','v2_clean',v2s,root,1,9,-1,v2s,1,1),
    ('initial wrong provider', 'v2_clean','v2_clean',v2s,foreign,1,0,-1,v2s,1,1),
    ('initial wrong mount ID', 'v2_clean','v2_clean',v2s,other_mount,1,0,-1,v2s,1,1),
    ('initial writable V2 slot', 'v2_clean','v2_clean',v2s,root,0,0,-1,v2s,1,1),
    ('WRITE_UNCERTAIN refuses even if clean', 'v2_clean','v2_clean',v2s|0o400000,root,1,0,-1,v2s|0o400000,0,0),
    ('legacy V1 recovery unaffected', 'v1','v1',v1s,root,0,0,0,3,1,1),
    ('legacy V1 replacement rejected', 'v2_clean','v1',v1s,root,0,0,-1,v1s,1,1),
    ('legacy zero replacement rejected', 'zero','v1',v1s,root,0,0,-1,v1s,1,1),
]

def number(n):
    return '-1' if n == -1 else '0%012o' % n

lines=['.data\n']
for name,words in records.items():
    assert len(words)==128
    lines.append('.globl record_%s_v1556\nrecord_%s_v1556:\n' % (name,name))
    lines.extend('        .word 0%012o\n' % word for word in words)
lines.append('.globl case_table_v1556\n.globl case_count_v1556\n')
lines.append('.equ case_count_v1556,%s\n' % number(len(cases)))
lines.append('case_table_v1556:\n')
for note,source,orig,media,vnode,policy,mode,ret,after,reads,invalid in cases:
    lines.append('        ; %s\n' % note)
    lines.extend('        .word %s\n' % value for value in (
        'record_%s_v1556' % source,'record_%s_v1556' % orig,
        *(number(v) for v in (media,vnode,policy,mode,ret,after,reads,invalid))))
(work/'physical-records-v1556.s').write_text(''.join(lines))

runtime=(repo/'system/kernel/fs/dtfs_runtime.s').read_text()
start=runtime.index('dtfs_identity_validate_v1522:\n')
parser=runtime[start:runtime.index('dtfs_lookup:\n',start)]
start=runtime.index('dtfs_identity_revalidate_v1522:\n')
guard=runtime[start:runtime.index('\n\n.if DTFS_ENABLE_FOREIGN\n; Compact directory enumeration.',start)]
bcache=(repo/'system/kernel/storage/bcache_pdp6.s').read_text()
start=bcache.index('bcache_workspace_invalidate:\n')
invalidate=bcache[start:bcache.index('\n        .bss',start)]
source=('.text\n.globl dtfs_identity_revalidate_v1522\n'
        '.globl bcache_workspace_invalidate\n'+parser+guard+invalidate)
assert source.count('pushj   17,dtfs_intent_validate_v1550')==1
assert source.count('trnn    5,0100000')==2
assert source.count('movei   7,0200')==1
assert source.count('came    3,5                     ; mount changed')==1

mutants=(
    ('bypass-v2-physical-validation',
     'pushj   17,dtfs_intent_validate_v1550',
     'setz    1,                       ; ignore V2 seal/state'),
    ('admit-dirty-v2',
     'jumpn   1,dtfs_identity_revalidate_pop_fail_v1522\n'
     '        ; Only DTVOL2/CLEAN',
     'jumpe   1,dtfs_identity_revalidate_pop_fail_v1522\n'
     '        ; Only DTVOL2/CLEAN'),
    ('wrong-v2-branch',
     'trnn    5,0100000              ; FORMAT_V2 on this mount',
     'trne    5,0100000              ; wrong record parser'),
    ('skip-scratch-clear',
     'setzm   (4)',
     'move    4,4                     ; stale RBN0 survives false read'),
    ('ignore-physical-read-failure',
     'jumpn   1,dtfs_identity_revalidate_pop_fail_v1522\n'
     '        move    5,(17)',
     'jumpe   1,dtfs_identity_revalidate_pop_fail_v1522\n'
     '        move    5,(17)'),
    ('skip-high-identity',
     'came    4,fs_block_workspace+1',
     'came    4,4'),
    ('skip-low-identity',
     'came    4,fs_block_workspace+2',
     'came    4,4'),
    ('ignore-pending-write-uncertain',
     'trne    5,0400000              ; WRITE_UNCERTAIN',
     'trne    5,0                    ; wrong suspect state'),
    ('skip-concurrent-media-change',
     'move    3,(4)\n        came    3,5',
     'move    3,5\n        came    3,5'),
    ('ignore-provider-change',
     'caie    3,5                     ; exact DTFS provider',
     'caie    3,6                     ; wrong provider'),
    ('ignore-mount-change',
     'came    3,7                     ; original published mount slot',
     'came    3,3                     ; wrong mount check'),
    ('ignore-readonly-policy',
     'trnn    1,1                     ; VFS_MOUNT_RDONLY still set',
     'trne    1,1                     ; wrong RO polarity'),
    ('skip-cache-tag-invalidation',
     'pushj   17,bcache_workspace_invalidate',
     'move    4,4                     ; old workspace BCACHE tag'),
    ('wrong-physical-rbn',
     'setz    2,                      ; reserved native RBN0',
     'movei   2,1                     ; wrong physical block'),
)
for name,old,new in mutants:
    assert source.count(old)==1,(name,source.count(old))
    (work/('mutant-'+name+'-v1556.s')).write_text(source.replace(old,new,1))
(work/'native-source-v1556.s').write_text(source)
print('v1556: %d native recovery cases, %d unsafe source mutations' % (len(cases),len(mutants)))
PY

run_case() {
    label=$1
    program=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 550000 --timeout 20 \
        --workdir "$work/run-$label" --name "dtfs-revalidate-$label-v1556" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-v2-revalidate-v1556.s" \
        "$work/physical-records-v1556.s" \
        "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_validate_v1550.s" \
        "$program" > "$work/$label.log" 2>&1
}

if ! run_case baseline "$work/native-source-v1556.s"; then
    tail -65 "$work/baseline.log" >&2
    echo 'FAIL v1556: native mounted V2 physical read-fault recovery' >&2
    exit 1
fi
echo 'PASS v1556: 29 native PDP-6 DTVOL2/V1 recovery cases'

for mutant in bypass-v2-physical-validation admit-dirty-v2 wrong-v2-branch \
    skip-scratch-clear ignore-physical-read-failure skip-high-identity \
    skip-low-identity ignore-pending-write-uncertain \
    skip-concurrent-media-change ignore-provider-change \
    ignore-mount-change ignore-readonly-policy skip-cache-tag-invalidation \
    wrong-physical-rbn; do
    if run_case "$mutant" "$work/mutant-$mutant-v1556.s"; then
        echo "FAIL v1556: unsafe recovery source mutant accepted: $mutant" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutant.log" || {
        echo "FAIL v1556: mutation did not reach native oracle: $mutant" >&2
        tail -30 "$work/$mutant.log" >&2
        exit 1
    }
    echo "PASS v1556: rejected $mutant"
done
echo 'PASS v1556: physically authenticated DTVOL2 RO recovery'
