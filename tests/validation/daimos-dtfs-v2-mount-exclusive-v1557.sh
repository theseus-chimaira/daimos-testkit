#!/bin/sh
# v1557: execute actual native PDP-6 unique physical V2 mount gate.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-mount-exclusive-v1557.XXXXXX")
if [ "${V1557_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys
repo,work=(Path(s) for s in sys.argv[1:])
source=(repo/'system/kernel/fs/dtfs_v2_mount_exclusive_v1557.s').read_text()
root=0o050101000000
root2=0o050201000000
foreign=0o060101000000
v2=0o100000

# physical unit, candidate is V2, existing root0/media0, root1/media1,
# expected status, and missing-table mode.
cases=[
    ('V2 first mount',3,1,0,0,0,0,0,0),
    ('V1 first mount',3,0,0,0,0,0,0,0),
    ('V2 conflicts V1 same unit',3,1,root,3,0,0,-1,0),
    ('V1 conflicts V2 same unit',3,0,root,v2|3,0,0,-1,0),
    ('V2 conflicts existing V2',3,1,root,v2|3,0,0,-1,0),
    ('V1/V1 remains compatible',3,0,root,3,0,0,0,0),
    ('V2 other physical unit safe',3,1,root,2,0,0,0,0),
    ('V1 other physical V2 safe',3,0,root,v2|2,0,0,0,0),
    ('unrelated provider cannot block V2',3,1,foreign,v2|3,0,0,0,0),
    ('unrelated provider cannot block V1',3,0,foreign,v2|3,0,0,0,0),
    ('retired V2 word cannot block V1',3,0,0,v2|3,0,0,0,0),
    ('retired V2 word cannot block V2',3,1,0,v2|3,0,0,0,0),
    ('V2 conflicting later slot V1',3,1,0,0,root2,3,-1,0),
    ('V1 conflicting later slot V2',3,0,0,0,root2,v2|3,-1,0),
    ('V2 conflicting later slot V2',3,1,0,0,root2,v2|3,-1,0),
    ('V1 both legacy slots same unit',3,0,root,3,root2,3,0,0),
    ('V2 another media unit but V2 later unit',3,1,root,2,root2,v2|2,0,0),
    ('V2 invalid physical unit negative',-1,1,0,0,0,0,-1,0),
    ('V2 invalid physical unit eight',8,1,0,0,0,0,-1,0),
    ('V1 invalid physical unit eight',8,0,0,0,0,0,-1,0),
    ('missing root table',3,1,0,0,0,0,-1,1),
    ('missing media table',3,1,0,0,0,0,-1,2),
    ('missing mount capacity',3,1,0,0,0,0,-1,3),
    ('V1 after old V1 plus foreign V2',3,0,root,3,foreign,v2|3,0,0),
    ('V2 on unit zero',0,1,root,3,0,0,0,0),
    ('V1 after V2 on unit zero',0,0,root,v2,0,0,-1,0),
]

lines=['.data\n.globl cases_v1557\n.globl case_count_v1557\n']
lines.append('.equ case_count_v1557,0%o\n' % len(cases))
lines.append('cases_v1557:\n')
for title,*values in cases:
    assert len(values)==8,(title,len(values))
    lines.append('        ; %s\n' % title)
    for value in values:
        lines.append('        .word %s\n' % ('-1' if value == -1 else '0%012o' % value))
(work/'cases-v1557.s').write_text(''.join(lines))

mutants=(
    ('skip-existing-provider',
     'caie    6,5                     ; DTFS only',
     'caie    6,6                     ; incorrect provider'),
    ('skip-physical-unit-match',
     'came    7,1',
     'camn    7,1'),
    ('allow-new-V2-on-V1',
     'jumpn   2,dtfs_v2_mount_conflict_v1557',
     'jumpe   2,dtfs_v2_mount_conflict_v1557'),
    ('allow-new-V1-on-V2',
     'trne    6,0100000              ; existing DTVOL2',
     'trnn    6,0100000              ; incorrect V2 state'),
    ('skip-later-slots',
     'sojg    5,dtfs_v2_mount_next_v1557',
     'jrst    dtfs_v2_mount_skip_v1557'),
    ('deny-retired-V2-slot',
     'caie    6,5                     ; DTFS only',
     'movei   6,5                    ; falsely claim stale slot'),
    ('allow-invalid-physical-unit',
     'caile   1,7',
     'caile   1,077'),
    ('bypass-mount-table-check',
     'jumpe   3,dtfs_v2_mount_conflict_v1557',
     'jumpe   3,dtfs_v2_mount_skip_v1557'),
)
for name,old,new in mutants:
    assert source.count(old)==1,(name,source.count(old))
    (work/('mutant-'+name+'-v1557.s')).write_text(source.replace(old,new,1))
print('v1557: %d native unit-ownership cases; %d mutants' % (len(cases),len(mutants)))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 240000 --timeout 20 \
        --workdir "$work/run-$label" --name "dtfs-unit-$label-v1557" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-v2-mount-exclusive-v1557.s" \
        "$work/cases-v1557.s" "$source" > "$work/$label.log" 2>&1
}
if ! run_case baseline "$DAIMOS_REPO/system/kernel/fs/dtfs_v2_mount_exclusive_v1557.s"; then
    tail -65 "$work/baseline.log" >&2
    echo 'FAIL v1557: native unique DTVOL2 unit ownership' >&2
    exit 1
fi
echo 'PASS v1557: 26 native PDP-6 V2/V1 physical-unit exclusivity cases'
for mutant in skip-existing-provider skip-physical-unit-match \
    allow-new-V2-on-V1 allow-new-V1-on-V2 skip-later-slots \
    deny-retired-V2-slot allow-invalid-physical-unit \
    bypass-mount-table-check; do
    if run_case "$mutant" "$work/mutant-$mutant-v1557.s"; then
        echo "FAIL v1557: unsafe unit ownership mutant accepted: $mutant" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutant.log" || {
        echo "FAIL v1557: mutant failed outside the native oracle: $mutant" >&2
        tail -28 "$work/$mutant.log" >&2
        exit 1
    }
    echo "PASS v1557: rejected $mutant"
done
echo 'PASS v1557: production DTVOL2 mount-unit exclusivity accepted'
