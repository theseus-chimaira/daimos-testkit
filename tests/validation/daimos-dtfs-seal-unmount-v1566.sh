#!/bin/sh
# Source-linked actual PDP-6 VFS final-unmount CLEAN sequencing v1566.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-seal-unmount-v1566.XXXXXX")
if [ "${V1566_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys
repo,work=(Path(x) for x in sys.argv[1:])
vfs=(repo/'system/kernel/fs/vfs.s').read_text()
def exact(start,stop):
    assert vfs.count(start)==1,(start,vfs.count(start))
    assert vfs.count(stop)==1,(stop,vfs.count(stop))
    return start + vfs.split(start,1)[1].split(stop,1)[0]

body=exact('vfs_unmount:\n', '; AC1=public mount ID.')
helpers=(exact('vfs_unmount_owner_check_v1523:\n',
               '; v1560: exact provider-private')+
         exact('vfs_dtfs_aux_empty_v1560:\n','; v1562: mount-owner')+
         exact('vfs_dtfs_quiesce_begin_v1562:\n',
               '; Release only the barrier')+
         exact('vfs_dtfs_quiesce_end_v1562:\n',
               '; Validate a zero-based,'))
source=('.text\n.globl vfs_unmount\n'
        '.globl vfs_dtfs_aux_empty_v1560\n'
        '.globl vfs_unmount_owner_check_v1523\n'
        '.globl vfs_dtfs_quiesce_begin_v1562\n'
        '.globl vfs_dtfs_quiesce_end_v1562\n' + body + helpers)
(work/'vfs-unmount-v1566.s').write_text(source)
assert body.count('movei   6,027')==1
assert body.count('trne    3,0640000')==1
assert body.count('trne    3,0400000')==1
assert body.count('pushj   17,vfs_unmount_owner_check_v1523')==3
assert body.count('pushj   17,vfs_dtfs_aux_empty_v1560')==2

v2,armed,seal,wr,rd=(0o100000,0o040000,0o020000,
                     0o400000,0o200000)
normal=v2|armed|3
root=0o050201000000
cases=[]
def case(label,mode=0,media=normal,aux=0,policy=0,owner=0,sync=0,
         result=0,root_after=0,media_after=None,aux_after=None,
         seal_calls=1,sync_calls=1,unlocks=1,owner_after=None):
    if media_after is None:
        media_after=(media & ~armed) if seal_calls else media
    if aux_after is None:
        aux_after=aux
    if owner_after is None:
        owner_after=owner
    cases.append((label,[mode,media,aux,policy,owner,sync,result,
                         root_after,media_after,aux_after,seal_calls,
                         sync_calls,unlocks,owner_after]))

case('armed writable V2 final CLEAN then retire')
case('failed partial physical CLEAN keeps seal and sticky WR',
     mode=1,result=-1,root_after=root,media_after=normal|seal|wr,
     unlocks=0)
case('MM shortage before physical IO clears transient seal for retry',
     mode=2,result=-1,root_after=root,media_after=normal,unlocks=0)
case('failed post-seal MM owner scan preserves mount',
     mode=3,result=-1,root_after=root,media_after=v2|3,
     aux_after=0o1234,unlocks=0)
case('remote FILE owner added during physical seal refuses retire',
     mode=4,result=-1,root_after=root,media_after=v2|3,
     owner_after=-1,unlocks=0)
case('lost exact root while I/O suspended cannot clear seal',
     mode=5,result=-1,root_after=0,media_after=v2|seal|3,
     unlocks=0)
case('RO cannot issue physical CLEAN even if ARMED forged',
     mode=6,policy=2,result=-1,root_after=root,media_after=normal,
     unlocks=0)
case('false provider success with WR_UNCERT must never retire',
     mode=7,result=-1,root_after=root,media_after=v2|seal|wr|3,
     unlocks=0)
case('false provider success with ARMED must never retire',
     mode=0o10,result=-1,root_after=root,media_after=normal,
     unlocks=0)
case('failed VFS SYNC retains mounted dirty owner without sealing',
     mode=0o11,sync=1,result=-1,root_after=root,
     media_after=normal,seal_calls=0,unlocks=0)
case('preexisting remote owner blocks VFS before quiescence',
     mode=0o12,owner=-1,result=-1,root_after=root,
     media_after=normal,seal_calls=0,sync_calls=0,unlocks=0)
case('preexisting MM owner refuses before physical SYNC',
     mode=0o13,aux=0o1234,result=-1,root_after=root,
     media_after=normal,seal_calls=0,sync_calls=0,unlocks=0)
case('preexisting READ_SUSPECT refuses quiescence',
     mode=0o14,media=normal|rd,result=-1,root_after=root,
     media_after=normal|rd,seal_calls=0,sync_calls=0,unlocks=0)
case('healthy RO V2 never invokes physical CLEAN',
     mode=0o15,media=v2|3,policy=2,media_after=v2|3,
     seal_calls=0)
case('unarmed synthetic RW V2 does not rewrite RBN0',
     mode=0o16,media=v2|3,media_after=v2|3,seal_calls=0)
case('legacy V1 unmount unchanged',
     mode=0o20,media=3,media_after=3,seal_calls=0)
case('preexisting WRITE_UNCERTAIN refuses quiescence',
     mode=0o21,media=normal|wr,result=-1,root_after=root,
     media_after=normal|wr,seal_calls=0,sync_calls=0,unlocks=0)
case('foreign owner published during sleeping SYNC prevents seal',
     mode=0o17,result=-1,root_after=root,media_after=normal,
     seal_calls=0,unlocks=0,owner_after=-1)

lines=['.data\n.globl cases_v1566\n.globl case_count_v1566\n',
       '.equ case_count_v1566,0%o\ncases_v1566:\n'%len(cases)]
for label, fields in cases:
    assert len(fields)==14
    lines.append('        ; %s\n'%label)
    lines.extend('        .word %s\n'%
                 ('-1' if x==-1 else '0%012o'%x) for x in fields)
(work/'cases-v1566.s').write_text(''.join(lines))

mutants=(
    ('skip-physical-seal',
     'pushj   17,fs_provider_reg_call\n'
     '        jumpn   1,vfs_unmount_fail\n'
     '        ; A successful return must',
     'setz    1,                     ; never called physical CLEAN\n'
     '        jumpn   1,vfs_unmount_fail\n'
     '        ; A successful return must'),
    ('skip-armed-gate',
     'trnn    3,0040000', 'trne    3,0040000'),
    ('skip-post-physical-sticky-check',
     'trne    3,0640000', 'trnn    3,0640000'),
    ('skip-post-physical-owner-scan',
     'pushj   17,vfs_unmount_owner_check_v1523',
     'setz    1,                      ; skipped second owner check'),
    ('skip-post-physical-MM-scan',
     'pushj   17,vfs_dtfs_aux_empty_v1560',
     'setz    1,                      ; skipped final owned MM check'),
    ('release-barrier-after-partial-write',
     'trne    3,0400000', 'trnn    3,0400000'),
)
for name,old,new in mutants:
    count=body.count(old)
    assert count>=1,(name,count)
    if name=='skip-post-physical-owner-scan':
        target=body.rfind(old)
        assert target!=-1
        altered=body[:target]+new+body[target+len(old):]
    elif name=='skip-post-physical-MM-scan':
        target=body.rfind(old)
        assert target!=-1
        altered=body[:target]+new+body[target+len(old):]
    else:
        altered=body.replace(old,new,1)
    (work/('unsafe-'+name+'-v1566.s')).write_text(source.replace(body,altered,1))
print('v1566: %d actual VFS unmount scenarios, %d unsafe mutations'%
      (len(cases),len(mutants)))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 500000 --timeout 20 \
        --workdir "$work/run-$label" --name "dtfs-clean-unmount-$label-v1566" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-seal-unmount-v1566.s" \
        "$work/cases-v1566.s" "$source" > "$work/$label.log" 2>&1
}
if ! run_case baseline "$work/vfs-unmount-v1566.s"; then
    tail -85 "$work/baseline.log" >&2
    echo 'FAIL v1566: actual resident VFS CLEAN and rollback flow' >&2
    exit 1
fi
echo 'PASS v1566: 18 actual native VFS unmount/seal/failure scenarios'
for mutant in skip-physical-seal skip-armed-gate \
    skip-post-physical-sticky-check skip-post-physical-owner-scan \
    skip-post-physical-MM-scan release-barrier-after-partial-write; do
    if run_case "$mutant" "$work/unsafe-$mutant-v1566.s"; then
        echo "FAIL v1566: unsafe VFS mutation accepted: $mutant" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutant.log" || {
        tail -45 "$work/$mutant.log" >&2
        echo "FAIL v1566: VFS mutation did not reach native oracle: $mutant" >&2
        exit 1
    }
    echo "PASS v1566: rejected unsafe $mutant"
done
echo 'PASS v1566: exact physical CLEAN under retained VFS unmount barrier'
