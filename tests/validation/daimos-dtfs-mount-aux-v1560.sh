#!/bin/sh
# v1560: actual PDP-6 VFS per-mount retained-MM owner emptiness gate.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-mount-aux-v1560.XXXXXX")
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
start=vfs.index('vfs_dtfs_aux_empty_v1560:\n')
end=vfs.index('\n; Validate a zero-based,',start)
source=('.text\n.globl vfs_dtfs_aux_empty_v1560\n'
        +vfs[start:end]+'\n')
assert 'skipn   (6)' in source
cases=[
    ('empty current slot zero',0,0,0,2,0,0),
    ('empty current slot one',1,0,0,2,0,0),
    ('retained on current first slot',0,0o1234,0,2,0,-1),
    ('retained on current second slot',1,0,0o1234,2,0,-1),
    ('other slot owner cannot block first',0,0,0o1234,2,0,0),
    ('other slot owner cannot block second',1,0o1234,0,2,0,0),
    ('both occupied first',0,0o1234,0o2345,2,0,-1),
    ('both occupied second',1,0o1234,0o2345,2,0,-1),
    ('full 18-bit physical base retained',0,0o777777,0,2,0,-1),
    ('negative slot refused',-1,0,0,2,0,-1),
    ('slot beyond capacity refused',2,0,0,2,0,-1),
    ('zero capacity refused',0,0,0,0,0,-1),
    ('capacity one slot zero valid',0,0,0,1,0,0),
    ('capacity one slot one refused',1,0,0,1,0,-1),
    ('missing backing table refused',0,0,0,2,1,-1),
    ('missing backing table with retired owner refused',1,0,0o1234,2,1,-1),
]
lines=['.data\n.globl cases_v1560\n.globl case_count_v1560\n',
       '.equ case_count_v1560,0%o\n' % len(cases),
       'cases_v1560:\n']
for case in cases:
    title,*values=case
    lines.append('        ; %s\n' % title)
    lines.extend('        .word %s\n' % ('-1' if v==-1 else '0%012o'%v)
                 for v in values)
(work/'cases-v1560.s').write_text(''.join(lines))
mutants=(
    ('accept-retained-MM', 'skipn   (6)', 'skipe   (6)'),
    ('read-wrong-mount-slot', 'add     6,1', 'addi    6,1'),
    ('accept-missing-base',
     'skipn   6,vfs_mount_aux_base_v1560\n        jrst    kret_neg1',
     'move    6,vfs_mount_aux_base_v1560\n        jumpn   6,kret_neg1'),
    ('accept-out-of-range', 'caml    1,vfs_mount_limit',
     'camge   1,vfs_mount_limit'),
    ('accept-negative-slot', 'jumpl   1,kret_neg1',
     'jumpge  1,kret_neg1'),
)
for label,old,new in mutants:
    assert source.count(old)==1,(label,source.count(old))
    (work/('mutant-'+label+'-v1560.s')).write_text(source.replace(old,new,1))
(work/'native-source-v1560.s').write_text(source)
print('v1560: %d actual PDP-6 owner cases, %d mutations' % (len(cases),len(mutants)))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 140000 --timeout 15 \
        --workdir "$work/run-$label" --name "dtfs-aux-$label-v1560" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-mount-aux-v1560.s" \
        "$work/cases-v1560.s" "$source" > "$work/$label.log" 2>&1
}
if ! run_case baseline "$work/native-source-v1560.s"; then
    tail -65 "$work/baseline.log" >&2
    echo 'FAIL v1560: actual PDP-6 MM scratch owner gate' >&2
    exit 1
fi
echo 'PASS v1560: 16 native PDP-6 provider-private mount MM cases'
for mutation in accept-retained-MM read-wrong-mount-slot \
    accept-missing-base accept-out-of-range accept-negative-slot; do
    if run_case "$mutation" "$work/mutant-$mutation-v1560.s"; then
        echo "FAIL v1560: unsafe MM ownership mutant accepted: $mutation" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutation.log" || {
        tail -35 "$work/$mutation.log" >&2
        echo "FAIL v1560: mutant failed outside native oracle: $mutation" >&2
        exit 1
    }
    echo "PASS v1560: rejected $mutation"
done
echo 'PASS v1560: retained MM owner cannot be discarded or reallocated'
