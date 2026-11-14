#!/bin/sh
# v1560: source-linked native VFS mount and unmount MM lifetime barrier.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-aux-lifecycle-v1560.XXXXXX")
if [ "${V1560_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys
repo,work=(Path(x) for x in sys.argv[1:])
vfs=(repo/'system/kernel/fs/vfs.s').read_text()
bridge=(repo/'system/kernel/fs/fs_mres.s').read_text()
assert 'd6fs_reader_slots_base:\nvfs_mount_aux_base_v1560:\n' in bridge

def leaf(start,stop):
    assert vfs.count(start)==1 and vfs.count(stop)==1,(start,stop)
    return start+vfs.split(start,1)[1].split(stop,1)[0]

source=(
    '.text\n.globl vfs_mount_found\n'
    '.globl vfs_unmount_after_prepare\n'
    '.globl vfs_dtfs_aux_empty_v1560\n'
    +leaf('vfs_mount_found:\n','; Publish one validated slot')
    +leaf('vfs_mount_publish_slot:\n','; int vfs_remount(node)')
    +leaf('vfs_unmount_after_prepare:\n','; Retire exactly one unmounted slot')
    +leaf('vfs_unmount_fail:\n','; AC1=public mount ID.')
    +leaf('vfs_dtfs_aux_empty_v1560:\n','; v1562: mount-owner')
)
assert source.count('pushj   17,vfs_dtfs_aux_empty_v1560')==2
assert 'move    2,(17)\n        movei   1,1(2)' in source
assert source.count('move    3,-1(17)               ; saved mounted root')==1

# mode 0=mount (previously unoccupied slot), 1=post-SYNC unmount;
# provider, slot, owner0, owner1, missing-base, expected status,
# unlocks, retires, expected root still published.
cases=[
    ('mount DTFS clear slot zero',0,5,0,0,0,0,0,0,0,1),
    ('mount DTFS retained owner blocked',0,5,0,0o1234,0,0,-1,0,0,0),
    ('mount DTFS unaffected by other slot owner',0,5,0,0,0o1234,0,0,0,0,1),
    ('mount DTFS slot one retained',0,5,1,0,0o1234,0,-1,0,0,0),
    ('mount DTFS missing aux table blocked',0,5,0,0,0,1,-1,0,0,0),
    ('mount D6FS boot reader unaffected',0,6,0,0o1234,0,0,0,0,0,1),
    ('mount TSFS unrelated provider unaffected',0,7,0,0o1234,0,0,0,0,0,1),
    ('unmount DTFS clear owner allowed',1,5,0,0,0,0,0,1,1,0),
    ('unmount DTFS retained owner refused',1,5,0,0o1234,0,0,-1,0,0,1),
    ('unmount DTFS slot one retained refused',1,5,1,0,0o1234,0,-1,0,0,1),
    ('unmount DTFS other slot owner allowed',1,5,1,0o1234,0,0,0,1,1,0),
    ('unmount D6FS reader owner unaffected',1,6,0,0o1234,0,0,0,1,1,0),
    ('unmount DTFS missing aux refused',1,5,0,0,0,1,-1,0,0,1),
    ('unmount TSFS owner unaffected',1,7,0,0o1234,0,0,0,1,1,0),
]
lines=['.data\n.globl cases_v1560\n.globl case_count_v1560\n',
       '.equ case_count_v1560,0%o\n'%len(cases),
       'cases_v1560:\n']
for title,*values in cases:
    assert len(values)==10,(title,len(values))
    lines.append('        ; %s\n'%title)
    lines.extend('        .word %s\n'%('-1' if v==-1 else '0%012o'%v)
                 for v in values)
(work/'cases-v1560.s').write_text(''.join(lines))

mutants=(
    ('mount-bypass-retained-owner',
     'pushj   17,vfs_dtfs_aux_empty_v1560\n'
     '        move    6,1                     ; preserve status across pop',
     'setz    1, ; owner lost on mount\n'
     '        move    6,1'),
    ('unmount-bypass-retained-owner',
     'pushj   17,vfs_dtfs_aux_empty_v1560\n'
     '        jumpn   1,vfs_unmount_fail',
     'setz    1, ; owner lost on unmount\n'
     '        jumpn   1,vfs_unmount_fail'),
    ('unmount-skip-provider-identity',
     'caie    3,5                     ; DTFS only',
     'caie    3,6                     ; DTFS guard wrongly skipped'),
    ('mount-skip-provider-identity',
     'caie    2,5                     ; DTFS_PROVIDER',
     'caie    2,6                     ; DTFS guard wrongly skipped'),
    ('unmount-skip-retained-refusal',
     'jumpn   1,vfs_unmount_fail\nvfs_unmount_aux_done_v1560:',
     'jumpe   1,vfs_unmount_fail\nvfs_unmount_aux_done_v1560:'),
)
for name,old,new in mutants:
    assert source.count(old)==1,(name,source.count(old))
    (work/('mutant-'+name+'-v1560.s')).write_text(source.replace(old,new,1))
(work/'native-source-v1560.s').write_text(source)
print('v1560: %d native VFS publication/unmount cases, %d mutations' %
      (len(cases),len(mutants)))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 230000 --timeout 18 \
        --workdir "$work/run-$label" --name "dtfs-aux-lifecycle-$label-v1560" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-aux-lifecycle-v1560.s" \
        "$work/cases-v1560.s" "$source" > "$work/$label.log" 2>&1
}
if ! run_case baseline "$work/native-source-v1560.s"; then
    tail -65 "$work/baseline.log" >&2
    echo 'FAIL v1560: actual native VFS mount or unmount lifetime' >&2
    exit 1
fi
echo 'PASS v1560: 14 native PDP-6 VFS mount/unmount lifetime cases'
for mutant in mount-bypass-retained-owner unmount-bypass-retained-owner \
    unmount-skip-provider-identity mount-skip-provider-identity \
    unmount-skip-retained-refusal; do
    if run_case "$mutant" "$work/mutant-$mutant-v1560.s"; then
        echo "FAIL v1560: unsafe VFS source mutant accepted: $mutant" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutant.log" || {
        tail -30 "$work/$mutant.log" >&2
        echo "FAIL v1560: source mutant did not reach native oracle: $mutant" >&2
        exit 1
    }
    echo "PASS v1560: rejected $mutant"
done
echo 'PASS v1560: source-linked VFS provider MM lifetime protected'
