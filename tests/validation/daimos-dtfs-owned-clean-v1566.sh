#!/bin/sh
# Real v1552 native MM lease reused for v1566 CLEAN, with explicit
# before-physical-I/O sticky uncertainty oracle and failure mutations.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-owned-clean-v1566.XXXXXX")
if [ "${V1566_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
python3 - "$DAIMOS_REPO" "$self" "$work" <<'PY'
from pathlib import Path
import sys
repo,self,work=(Path(s) for s in sys.argv[1:])
source=(repo/'system/kernel/fs/dtfs_intent_owned_arm_v1552.s').read_text()
fixture=(self/'daimos-dtfs-owned-scratch-v1552.s').read_text()
assert fixture.count('pushj   17,dtfs_intent_owned_arm_v1552') == 1
assert fixture.count('dtfs_intent_arm_v1551:\n') == 1
assert fixture.count('dtfs_intent_clean_v1566:\n') == 1
assert fixture.count('dtfs_mark_unit_suspect_v1522:\n') == 1
fixture=fixture.replace('dtfs_intent_owned_arm_v1552',
                        'dtfs_intent_owned_clean_v1566')
fixture=fixture.replace('dtfs_intent_arm_v1551:\n',
                        'test_clean_stub_swap_v1566:\n',1)
fixture=fixture.replace('dtfs_intent_clean_v1566:\n',
                        'dtfs_intent_arm_v1551:\n',1)
fixture=fixture.replace('test_clean_stub_swap_v1566:\n',
                        'dtfs_intent_clean_v1566:\n',1)
old=('dtfs_mark_unit_suspect_v1522:\n'
     '        seto    1,\n'
     '        popj    17,')
assert fixture.count(old)==1
fixture=fixture.replace(old, '''dtfs_mark_unit_suspect_v1522:
        caie    1,2
        jrst    bad_mm_call_v1552
        caie    2,0400000
        jrst    bad_mm_call_v1552
        aos     poison_count_v1566
        popj    17,''',1)
assert '        aos     arm_calls_v1552\n' in fixture
fixture=fixture.replace('        aos     arm_calls_v1552\n',
                        '        aos     arm_calls_v1552\n'
                        '        move    5,poison_count_v1566\n'
                        '        caie    5,1\n'
                        '        jrst    bad_mm_call_v1552\n',1)
anchor=('        move    1,arm_calls_v1552\n'
        '        came    1,6(014)\n'
        '        jrst    case_bad_v1552\n')
assert fixture.count(anchor)==1
fixture=fixture.replace(anchor,anchor+
                        '        move    1,poison_count_v1566\n'
                        '        came    1,6(014)\n'
                        '        jrst    case_bad_v1552\n',1)
fixture=fixture.replace('        setzm   arm_calls_v1552\n',
                        '        setzm   arm_calls_v1552\n'
                        '        setzm   poison_count_v1566\n',1)
assert fixture.count('arm_calls_v1552: .block 1') == 1
fixture=fixture.replace('arm_calls_v1552: .block 1',
                        'arm_calls_v1552: .block 1\n'
                        'poison_count_v1566: .block 1',1)
(work/'owned-clean-fixture-v1566.s').write_text(fixture)

mutants = (
    ('not-clean-dispatch',
     'movei   5,2                     ; final DIRTY -> CLEAN',
     'setz    5,                      ; calls ARM instead'),
    ('skip-pre-io-poison',
     'pushj   17,dtfs_mark_unit_suspect_v1522',
     'move    1,1                   ; no uncertainty marker'),
    ('skip-mm-pin', 'pushj   17,mm_pin',
     'setz    1,                      ; forgot physical pin'),
    ('skip-mm-unpin', 'pushj   17,mm_unpin',
     'setz    1,                      ; forgot physical unpin'),
    ('skip-mm-free', 'pushj   17,mm_free',
     'setz    1,                      ; forgot physical free'),
    ('forget-retained-MM',
     'dtfs_owned_arm_release_fail_v1552:\n',
     'dtfs_owned_arm_release_fail_v1552:\n'
     '        setzm   (013) ; lost leaked physical scratch\n'),
    ('skip-existing-owner',
     'skipn   (013)                   ; prevent overwriting a leaked owner',
     'skipe   (013)                   ; overwrites foreign owner'),
)
for name,old,new in mutants:
    assert source.count(old)==(2 if name=='skip-mm-free' else 1),(
        name,source.count(old))
    (work/('unsafe-'+name+'-v1566.s')).write_text(source.replace(old,new,1))
print('v1566: 11 real MM lease CLEAN cases; 7 source mutations')
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 240000 --timeout 20 \
        --workdir "$work/run-$label" --name "dtfs-owned-clean-$label-v1566" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$work/owned-clean-fixture-v1566.s" \
        "$source" > "$work/$label.log" 2>&1
}
if ! run_case baseline "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_owned_arm_v1552.s"; then
    tail -85 "$work/baseline.log" >&2
    echo 'FAIL v1566: real pinned MM CLEAN lease' >&2
    exit 1
fi
echo 'PASS v1566: 11 actual PDP-6 MM CLEAN pin/physical/cleanup cases'
for mutant in not-clean-dispatch skip-pre-io-poison skip-mm-pin \
    skip-mm-unpin skip-mm-free forget-retained-MM skip-existing-owner; do
    if run_case "$mutant" "$work/unsafe-$mutant-v1566.s"; then
        echo "FAIL v1566: accepted unsafe MM CLEAN mutant $mutant" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutant.log" || {
        tail -40 "$work/$mutant.log" >&2
        echo "FAIL v1566: MM mutant never reached oracle: $mutant" >&2
        exit 1
    }
    echo "PASS v1566: rejected unsafe $mutant"
done
echo 'PASS v1566: exact pinned MM scratch reused for physical CLEAN'
