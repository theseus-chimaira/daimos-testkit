#!/bin/sh
# v1558: execute real PDP-6 poisoned-media replacement preflight after
# false-successful partial Type-551 reads. No filesystem is retired here.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-replace-preflight-v1558.XXXXXX")
if [ "${V1558_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/mkdtfs-v1558" "$DAIMOS_REPO/tools/host/mkdtfs.c"
"$work/mkdtfs-v1558" -o "$work/original.tap"
"$work/mkdtfs-v1558" -o "$work/replacement.tap"
"$work/mkdtfs-v1558" --durable-v1550 -o "$work/foreign-v2.tap"

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys
repo,work=(Path(s) for s in sys.argv[1:])
mask=0o777777777777

def record(name,rbn):
    with (work/name).open('rb') as f:
        f.seek(rbn*128*8)
        data=f.read(128*8)
    assert len(data)==1024
    out=[]
    for i in range(0,len(data),8):
        hi=int.from_bytes(data[i:i+4],'little')
        lo=int.from_bytes(data[i+4:i+8],'little')
        assert hi<=0o777777 and lo<=0o777777
        out.append((hi<<18)|lo)
    return out

first=record('original.tap',0)
second=record('replacement.tap',0)
v2=record('foreign-v2.tap',0)
directory=record('replacement.tap',0o144)
zero=[0]*128
modified=second[:]
modified[2]=(modified[2]+1)&mask
modified[3]=(~(modified[0]^modified[1]^modified[2]))&mask
assert first[0]==second[0]==0o446466575421
assert v2[0]==0o446466575422
assert first[1:3]!=second[1:3]
assert directory[0]>>31==0o36 and directory[-1]==0o446446632021

records={'v1a':first,'v1b':second,'v1b_changed':modified,'v2':v2,
         'zero':zero,'dir':directory}
media=0o400003
cases=[
    ('healthy different V1 replacement','v1b',0,media,'v1a',0,2,1),
    ('same original must not retire','v1a',0,media,'v1a',-1,2,1),
    ('false-successful empty directory read','v1b',1,media,'v1a',-1,1,1),
    ('false-successful short directory read','v1b',2,media,'v1a',-1,1,1),
    ('physical directory read failure','v1b',3,media,'v1a',-1,1,1),
    ('damaged directory magic','v1b',4,media,'v1a',-1,1,1),
    ('missing reserved RBN0 owner','v1b',5,media,'v1a',-1,1,1),
    ('missing reserved RBN0144 owner','v1b',6,media,'v1a',-1,1,1),
    ('damaged native tail tags','v1b',7,media,'v1a',-1,1,1),
    ('false-successful empty identity read','v1b',0o10,media,'v1a',-1,2,1),
    ('false-successful short identity read','v1b',0o11,media,'v1a',-1,2,1),
    ('physical RBN0 read failure','v1b',0o12,media,'v1a',-1,2,1),
    ('torn V1 checksum','v1b',0o13,media,'v1a',-1,2,1),
    ('nonzero reserved identity padding','v1b',0o14,media,'v1a',-1,2,1),
    ('cannot replace V1 with V2 here','v2',0,media,'v1a',-1,2,1),
    ('cannot replace with zero legacy','zero',0,media,'v1a',-1,2,1),
    ('missing original high ID','v1b',0o20,media,'v1a',-1,0,0),
    ('missing original low ID','v1b',0o21,media,'v1a',-1,0,0),
    ('requires WRITE_UNCERTAIN','v1b',0,3,'v1a',-1,0,0),
    ('rechecked different valid low ID','v1b_changed',0,media,'v1a',0,2,1),
]

def word(n):
    return '-1' if n==-1 else '0%012o' % n

lines=['.data\n']
for name,words in records.items():
    assert len(words)==128
    lines.append('.globl record_%s_v1558\nrecord_%s_v1558:\n' % (name,name))
    lines.extend('        .word '+word(n)+'\n' for n in words)
lines.append('.globl cases_v1558\n.globl case_count_v1558\n')
lines.append('.equ case_count_v1558,0%o\ncases_v1558:\n' % len(cases))
for desc,name,mode,status,original,ret,raw,flush in cases:
    lines.append('        ; '+desc+'\n')
    values=('record_%s_v1558'%name,word(mode),word(status),
            'record_%s_v1558'%original,word(ret),word(raw),word(flush))
    lines.extend('        .word '+v+'\n' for v in values)
(work/'real-media-v1558.s').write_text(''.join(lines))

runtime=(repo/'system/kernel/fs/dtfs_runtime.s').read_text()
start=runtime.index('dtfs_verify_replacement_v1531:\n')
replacement=runtime[start:runtime.index('        .data\ndtfs_mres_vector:',start)]
start=runtime.index('dtfs_workspace_clear_v1558:\n')
clear=runtime[start:runtime.index('; Shared LEGACY native identity parser',start)]
start=runtime.index('dtfs_identity_validate_v1522:\n')
validator=runtime[start:runtime.index('dtfs_lookup:\n',start)]
source=('.text\n.globl dtfs_verify_replacement_v1531\n'+
        replacement+clear+validator)
assert source.count('pushj   17,dtfs_workspace_clear_v1558')==1
assert source.count('pushj   17,dtfs_workspace_poison_v1558')==1
mutants=(
    ('skip-directory-scratch-clear',
     'pushj   17,dtfs_workspace_clear_v1558',
     'move    4,4                    ; trust stale directory'),
    ('skip-native-directory-magic',
     'came    1,[0446446632021]',
     'came    1,1'),
    ('skip-reserved-directory-owner',
     'move    1,fs_block_workspace+016',
     'move    1,[0360000000000]'),
    ('skip-id-checksum',
     'came    1,fs_block_workspace+3',
     'came    1,1'),
    ('admit-original-same-identity',
     'camn    4,fs_block_workspace+2 ; both halves equal: old medium',
     'came    4,fs_block_workspace+2 ; wrong same-ID test'),
    ('skip-cache-invalidation',
     'pushj   17,bcache_invalidate_all',
     'move    4,4                    ; leaves stale clean tags'),
)
for name,old,new in mutants:
    assert source.count(old)==1,(name,source.count(old))
    (work/('mutant-'+name+'-v1558.s')).write_text(source.replace(old,new,1))
(work/'replacement-source-v1558.s').write_text(source)
print('v1558: %d native replacement cases, %d unsafe mutants' % (len(cases),len(mutants)))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 600000 --timeout 20 \
        --workdir "$work/run-$label" --name "dtfs-replace-$label-v1558" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-replace-raw-preflight-v1558.s" \
        "$work/real-media-v1558.s" "$source" > "$work/$label.log" 2>&1
}
if ! run_case baseline "$work/replacement-source-v1558.s"; then
    tail -65 "$work/baseline.log" >&2
    echo 'FAIL v1558: native physical replacement admission' >&2
    exit 1
fi
echo 'PASS v1558: 20 native physical replacement preflight scenarios'
for mutant in skip-directory-scratch-clear skip-native-directory-magic \
    skip-reserved-directory-owner skip-id-checksum \
    admit-original-same-identity skip-cache-invalidation; do
    if run_case "$mutant" "$work/mutant-$mutant-v1558.s"; then
        echo "FAIL v1558: admitted unsafe replacement mutation $mutant" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutant.log" || {
        echo "FAIL v1558: replacement mutant failed outside oracle $mutant" >&2
        tail -30 "$work/$mutant.log" >&2
        exit 1
    }
    echo "PASS v1558: rejected $mutant"
done
echo 'PASS v1558: poisoned-media replacement raw preflight accepted'
