#!/bin/sh
# Source-linked native PDP-6 v1561 physical-unit -> retained intent gate.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-intent-mount-v1561.XXXXXX")
if [ "${V1561_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo,work=(Path(s) for s in sys.argv[1:])
source=(repo/'system/kernel/fs/dtfs_intent_mount_gate_v1561.s').read_text()
assert source.count('pushj   17,dtfs_intent_first_write_v1553')==1
assert source.count('move    013,vfs_mount_aux_base_v1560')==1
v2=0o100000
armed=0o40000
uncertain=0o400000
r0=0o050101000000
r1=0o050201000000
foreign=0o060101000000
owner=0o12345 << 18

def case(label, unit=3, roots=(r0,0), media=(3,0), aux=(0,0),
         policy=0, missing=0, mode=0, expected=0, calls=0, slot=0):
    return dict(label=label,unit=unit,roots=list(roots),media=list(media),
                aux=list(aux),policy=policy,missing=missing,mode=mode,
                expected=expected,calls=calls,slot=slot)

cases=[
    case('ordinary V1 physical write accepted'),
    case('legacy V1 multiple mounts preserved',roots=(r0,r1),media=(3,3)),
    case('retired old V2 word ignored',roots=(0,0),media=(v2|3,0)),
    case('V2 first arm uses exact slot 0 MM basep',media=(v2|3,0),calls=1),
    case('V2 already armed still checks lower layer',media=(v2|armed|3,0),calls=1),
    case('V2 RO forbidden before dirty marker',media=(v2|3,0),policy=1,expected=-1),
    case('later V2 mount uses exact slot 1 basep',roots=(0,r1),
         media=(0,v2|3),calls=1,slot=1),
    case('later V2 RO forbidden',roots=(0,r1),media=(0,v2|3),
         policy=2,expected=-1,slot=1),
    case('UID/GID left half preserved',media=(owner|v2|3,0),calls=1),
    case('later V2 owner preserved',roots=(0,r1),
         media=(0,owner|v2|3),calls=1,slot=1),
    case('V1 plus V2 same physical unit refused',roots=(r0,r1),
         media=(3,v2|3),expected=-1,slot=1),
    case('two V2 mounts same unit refused',roots=(r0,r1),
         media=(v2|3,v2|3),expected=-1),
    case('V2 published with wrong slot ID refused',roots=(r1,0),
         media=(v2|3,0),expected=-1),
    case('V2 wrong ID in later slot refused',roots=(0,r0),
         media=(0,v2|3),expected=-1),
    case('non-DTFS provider never owns a V2 gate',roots=(foreign,0),
         media=(v2|3,0)),
    case('V2 on DTC2 cannot block physical DTC3',media=(v2|2,0)),
    case('V1 on unit3 plus V2 on unit2 preserved',roots=(r0,r1),
         media=(3,v2|2)),
    case('V2 on unit3 plus V1 on unit2 succeeds',roots=(r0,r1),
         media=(v2|3,2),calls=1),
    case('missing root table refused',missing=1,expected=-1),
    case('missing media table refused',missing=2,expected=-1),
    case('missing owner table refuses V2',media=(v2|3,0),
         missing=3,expected=-1),
    case('legacy V1 unaffected by missing owner table',missing=3),
    case('zero mount limit refused',missing=4,expected=-1),
    case('negative physical unit refused',unit=-1,expected=-1),
    case('out-of-range physical unit refused',unit=8,expected=-1),
    case('occupied V2 owner slot0 refused',media=(v2|3,0),
         aux=(0o1234,0),expected=-1),
    case('occupied V2 owner slot1 refused',roots=(0,r1),
         media=(0,v2|3),aux=(0,0o1234),expected=-1,slot=1),
    case('unrelated slot owner does not block',media=(v2|3,0),
         aux=(0,0o1234),calls=1),
    case('physical intent operation failure refused',media=(v2|3,0),
         mode=1,expected=-1,calls=1),
    case('MM cleanup failure retains exact base',media=(v2|3,0),
         mode=2,expected=-1,calls=1),
    case('changed root during sleeping I/O refused',media=(v2|3,0),
         mode=3,expected=-1,calls=1),
    case('changed media during sleeping I/O refused',media=(v2|3,0),
         mode=4,expected=-1,calls=1),
    case('lost RW policy during sleeping I/O refused',media=(v2|3,0),
         mode=5,expected=-1,calls=1),
    case('false success retains MM owner refused',media=(v2|3,0),
         mode=6,expected=-1,calls=1),
    case('already armed V2 in later slot revalidates',roots=(0,r1),
         media=(0,v2|armed|3),calls=1,slot=1),
]

lines=['.data\n.globl cases_v1561\n.globl case_count_v1561\n',
       '.equ case_count_v1561,0%o\n'%len(cases),
       'cases_v1561:\n']
for c in cases:
    roots=list(c['roots'])
    media=list(c['media'])
    aux=list(c['aux'])
    policy=c['policy']
    if c['calls']:
        index=c['slot']
        if c['mode'] not in (1,2):
            media[index] |= armed
        if c['mode']==2 or c['mode']==6:
            aux[index]=0o7777
        if c['mode']==3:
            roots[index]=foreign
        if c['mode']==4:
            media[index] |= uncertain
        if c['mode']==5:
            policy |= 1 << index
    values=[c['unit'],c['roots'][0],c['media'][0],c['roots'][1],
            c['media'][1],c['aux'][0],c['aux'][1],c['policy'],
            c['missing'],c['mode'],c['expected'],c['calls'],
            roots[0],media[0],roots[1],media[1],aux[0],aux[1],
            policy,c['slot']]
    assert len(values)==20
    lines.append('        ; %s\n'%c['label'])
    lines.extend('        .word %s\n'%('-1' if n==-1 else '0%012o'%n)
                 for n in values)
(work/'cases-v1561.s').write_text(''.join(lines))

mutants=(
    ('skip-lower-physical-gate',
     'pushj   17,dtfs_intent_first_write_v1553',
     'setz    1, ; falsely skip physical DIRTY verification'),
    ('wrong-MM-owner-slot',
     'add     013,4                   ; EXACT retained per-mount basep',
     'move    013,vfs_mount_aux_base_v1560 ; wrong fixed slot owner'),
    ('disable-RO-before-DIRTY',
     'trne    6,1\n        jrst    dtfs_mount_gate_refuse_v1561\n'
     '        move    013,vfs_mount_aux_base_v1560',
     'trnn    6,1\n        jrst    dtfs_mount_gate_refuse_v1561\n'
     '        move    013,vfs_mount_aux_base_v1560'),
    ('allow-duplicated-physical-V2',
     'caie    7,1                     ; V2 requires ONE unit owner',
     'caie    7,2                     ; wrong owner count'),
    ('ignore-original-root-identity',
     'came    6,014', 'came    6,6'),
    ('ignore-original-media-identity',
     'came    6,015', 'came    6,6'),
    ('ignore-retained-MM-after-IO',
     'skipn   (013)\n        jrst    dtfs_mount_gate_post_owner_v1561',
     'skipn   013\n        jrst    dtfs_mount_gate_post_owner_v1561'),
    ('ignore-V2-media-flag',
     'trnn    5,0100000', 'trne    5,0100000'),
    ('ignore-physical-unit-match',
     'came    6,010', 'came    6,6'),
    ('ignore-published-provider',
     'caie    5,5                     ; only published DTFS roots',
     'caie    5,6                     ; wrong provider'),
    ('ignore-public-mount-ID',
     'came    6,2', 'came    6,6'),
    ('ignore-physical-error',
     'jumpn   1,dtfs_mount_gate_refuse_v1561\n'
     '\n        ; All I/O above may sleep.',
     'jumpe   1,dtfs_mount_gate_refuse_v1561\n'
     '\n        ; All I/O above may sleep.'),
    ('allow-out-of-range-unit',
     'caile   010,7', 'caile   010,077'),
)
for label,old,new in mutants:
    assert source.count(old)==1,(label,source.count(old))
    (work/('mutant-'+label+'-v1561.s')).write_text(source.replace(old,new,1))
print('v1561: %d native mounted-intent cases, %d unsafe mutations' %
      (len(cases),len(mutants)))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 300000 --timeout 18 \
        --workdir "$work/run-$label" --name "dtfs-intent-$label-v1561" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-intent-mount-v1561.s" \
        "$work/cases-v1561.s" "$source" > "$work/$label.log" 2>&1
}
if ! run_case baseline "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_mount_gate_v1561.s"; then
    tail -65 "$work/baseline.log" >&2
    echo 'FAIL v1561: actual native per-mount physical intent bridge' >&2
    exit 1
fi
echo 'PASS v1561: 35 actual native PDP-6 mounted intent/owner cases'
for mutant in skip-lower-physical-gate wrong-MM-owner-slot \
    disable-RO-before-DIRTY allow-duplicated-physical-V2 \
    ignore-original-root-identity ignore-original-media-identity \
    ignore-retained-MM-after-IO ignore-V2-media-flag \
    ignore-physical-unit-match ignore-published-provider \
    ignore-public-mount-ID ignore-physical-error allow-out-of-range-unit; do
    if run_case "$mutant" "$work/mutant-$mutant-v1561.s"; then
        echo "FAIL v1561: accepted unsafe physical intent mutant: $mutant" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutant.log" || {
        tail -35 "$work/$mutant.log" >&2
        echo "FAIL v1561: mutant failed outside native oracle: $mutant" >&2
        exit 1
    }
    echo "PASS v1561: rejected $mutant"
done
echo 'PASS v1561: production mounted V2 intent/retained MM gate'
