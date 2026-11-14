#!/bin/sh
# Native PDP-6 production MRES final CLEAN owner/admission/rollback matrix.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-seal-owner-v1566.XXXXXX")
if [ "${V1566_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys
repo, work = (Path(s) for s in sys.argv[1:])
src = (repo / 'system/kernel/fs/dtfs_intent_mount_seal_v1566.s').read_text()
v2, armed, seal, uncertain, suspect = (0o100000, 0o040000,
                                      0o020000, 0o400000, 0o200000)
normal = v2 | armed | seal | 3
r0, r1, foreign = 0o050101000000, 0o050201000000, 0o060101000000
ids = (0o1234567, 0o3456701)

cases = []
def case(label, slot=0, roots=None, media=None, aux=None, policy=0,
         mode=0, missing=0, idhi=ids[0], idlo=ids[1],
         passed=0, expected=None, calls=None, root_arg=None):
    if roots is None:
        roots = [r0, 0]
    else:
        roots = list(roots)
    if media is None:
        media = [normal, 0]
    else:
        media = list(media)
    if aux is None:
        aux = [0, 0]
    else:
        aux = list(aux)
    if root_arg is None:
        root_arg = r0 if slot == 0 else r1
    if calls is None:
        calls = 1 if passed else 0
    if expected is None:
        result = list(media)
        if passed:
            result[slot] &= ~(armed | uncertain)
        elif calls:
            if mode != 2 and mode != 8:
                result[slot] |= uncertain
            if mode == 5:
                result[slot] |= suspect
        expected = result
    if calls and mode == 3:
        aux[slot] = 0o1234   # simulated retained MM owner
    if calls and mode == 9:
        aux[slot] = 0o1234
    if calls and mode == 4:
        roots[slot] = 0
    if calls and mode == 7:
        policy |= 1 << slot
    values = [slot, roots[0], roots[1], media[0], media[1],
              0, 0,  # initial MM scratch owners, nonzero set below
              0,     # initial policy, replaced below
              mode, missing, idhi, idlo, root_arg,
              0 if passed else -1, calls,
              expected[0], expected[1], aux[0], aux[1],
              roots[0], roots[1]]
    # For mode 3/4/7/9, only callback changes these fields. The fixture
    # must begin with the original owner/aux/flags and expect the mutation.
    values[1] = (r0 if slot == 0 else 0) if mode == 4 else roots[0]
    values[2] = r1 if mode == 4 and slot == 1 else roots[1]
    values[5] = 0 if mode in (3,9) else aux[0]
    values[6] = 0 if mode in (3,9) else aux[1]
    values[7] = policy & ~(1 << slot) if mode == 7 else policy
    cases.append((label, values))

case('exact V2 slot zero seal success', passed=1)
case('exact V2 slot one seal success', slot=1,
     roots=[0, r1], media=[0, normal], passed=1)
case('high owner left half intact', media=[(0o12345 << 18)|normal, 0],
     passed=1)
case('slot one owner left half intact', slot=1,
     roots=[0, r1], media=[0,(0o777 << 18)|normal], passed=1)
case('read-only mount must refuse', policy=1)
case('read-only later slot refuses', slot=1, roots=[0,r1],
     media=[0,normal], policy=2)
case('unsealed mount refuses', media=[normal & ~seal,0])
case('unarmed mount refuses', media=[normal & ~armed,0])
case('legacy V1 cannot CLEAN', media=[3,0])
case('foreign personality cannot CLEAN',media=[normal | 0o10,0])
case('already WRITE_UNCERTAIN refuses',media=[normal | uncertain,0])
case('READ_SUSPECT refuses',media=[normal | suspect,0])
case('wrong requested root refused',root_arg=r1)
case('wrong actual provider refused',roots=[foreign,0])
case('wrong actual public slot ID refused', roots=[r1,0])
case('absent published root refused',roots=[0,0])
case('negative slot refused',slot=-1,root_arg=r0)
case('beyond mount capacity refused',slot=2,root_arg=r0)
case('no root slab refused',missing=1)
case('no media slab refused',missing=2)
case('no MM aux slab refused',missing=4)
case('no saved high ID slab refused',missing=8)
case('no saved low ID slab refused',missing=16)
case('zero mount table capacity refused',missing=32)
case('zero saved high ID refused',idhi=0)
case('zero saved low ID refused',idlo=0)
case('retained MM scratch refuses',aux=[0o1234,0])
case('other slot retained MM does not block',aux=[0,0o1234],passed=1)
case('physical CLEAN failure leaves sticky',mode=1,calls=1)
case('MM allocation failure before IO permits retry',mode=2,calls=1)
case('failed MM cleanup retains base and poison',mode=3,calls=1)
case('lost published root after physical IO retains poison',mode=4,calls=1)
case('read-suspect during IO preserves both failures',mode=5,calls=1)
case('saved identity changed during IO refuses',mode=6,calls=1)
case('policy changed to RO during IO refuses',mode=7,calls=1)
case('false success without uncertainty marker refuses',mode=8,calls=1)
case('false success with retained MM owner refuses',mode=9,calls=1)

lines = ['.data\n.globl cases_v1566\n.globl case_count_v1566\n',
         '.equ case_count_v1566,0%o\ncases_v1566:\n' % len(cases)]
for label, values in cases:
    assert len(values) == 21
    lines.append('        ; %s\n' % label)
    for value in values:
        lines.append('        .word %s\n' %
                     ('-1' if value == -1 else '0%012o' % value))
(work / 'cases-v1566.s').write_text(''.join(lines))

mutants = (
    ('permit-RO-seal','trne    6,1', 'trnn    6,1'),
    ('permit-unsealed-seal',
     'trnn    013,0020000', 'trne    013,0020000'),
    ('permit-unarmed-seal',
     'trnn    013,0040000', 'trne    013,0040000'),
    ('permit-write-uncertain',
     'trne    013,0600030', 'trnn    013,0600030'),
    ('permit-MM-owner',
     'skipn   (014)\n        jrst    dtfs_seal_get_id_v1566',
     'skipe   (014)\n        jrst    dtfs_seal_get_id_v1566'),
    ('forget-physical-clean',
     'pushj   17,dtfs_intent_owned_clean_v1566',
     'setz    1,                         ; bypassed real CLEAN'),
    ('accept-missing-uncertainty-marker',
     'came    1,2\n        jrst    dtfs_seal_refuse_v1566',
     'move    1,1\n        jrst    dtfs_seal_no_media_check_v1566\n'
     'dtfs_seal_no_media_check_v1566:'),
    ('clear-quiescence-too-early',
     'movei   2,0440000', 'movei   2,0460000'),
    ('clear-only-armed-leave-uncertain',
     'movei   2,0440000', 'movei   2,0040000'),
    ('wrong-ID-recheck',
     'came    2,015', 'camn    2,015'),
)
for name, old, new in mutants:
    assert src.count(old) >= 1, (name, src.count(old))
    (work / ('unsafe-%s-v1566.s' % name)).write_text(
        src.replace(old, new, 1))
print('v1566: %d actual mounted owner cases; %d mutations' %
      (len(cases), len(mutants)))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 480000 --timeout 20 \
        --workdir "$work/run-$label" --name "dtfs-seal-owner-$label-v1566" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-seal-owner-v1566.s" \
        "$work/cases-v1566.s" "$source" > "$work/$label.log" 2>&1
}
if ! run_case baseline "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_mount_seal_v1566.s"; then
    tail -95 "$work/baseline.log" >&2
    echo 'FAIL v1566: real mounted owner seal guard' >&2
    exit 1
fi
echo 'PASS v1566: 37 actual mounted V2 ownership and MM guard scenarios'
for label in permit-RO-seal permit-unsealed-seal permit-unarmed-seal \
    permit-write-uncertain permit-MM-owner forget-physical-clean \
    accept-missing-uncertainty-marker clear-quiescence-too-early \
    clear-only-armed-leave-uncertain wrong-ID-recheck; do
    if run_case "$label" "$work/unsafe-$label-v1566.s"; then
        echo "FAIL v1566: unsafe mount-seal mutation accepted: $label" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$label.log" || {
        tail -60 "$work/$label.log" >&2
        echo "FAIL v1566: mutation did not reach native oracle: $label" >&2
        exit 1
    }
    echo "PASS v1566: rejected unsafe $label"
done
echo 'PASS v1566: exact mounted owner, MM lease and physical seal binding'
