#!/bin/sh
# v1554: real PDP-6 MM extent, pin and free through the shared verify entry.
# The actual DTVOL2 physical verify routine is covered separately in v1554.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-verify-real-mm-v1554.XXXXXX")
if [ "${V1554_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$self" "$work" <<'PY'
from pathlib import Path
import sys
repo,self,work=(Path(x) for x in sys.argv[1:])

mm=(repo/'system/kernel/mm/mm_pdp6.s').read_text()
def leaf(first,last):
    assert mm.count(first)==1,(first,mm.count(first))
    assert mm.count(last)==1,(last,mm.count(last))
    return first + mm.split(first,1)[1].split(last,1)[0]

decls=('.text\n.globl mm_alloc_aligned_noreclaim\n'
       '.globl mm_extent_insert\n.globl mm_find_fit\n'
       '.globl mm_free\n.globl mm_pin\n.globl mm_unpin\n'
       '.globl mm_is_pinned\n')
constants='\n'.join(s for s in mm.splitlines()
                    if s.startswith('        .equ    '))+'\n'
parts=(leaf('mm_delete:\n','\n; Find a fitting free gap.')+
       leaf('mm_find_fit:\n','\n; int mm_alloc_aligned_noreclaim')+
       leaf('mm_alloc_aligned_noreclaim:\n','\n; Move one process extent')+
       leaf('mm_free:\n','\n; int mm_process_transfer_pinned')+
       leaf('mm_pin_adjust:\n','\n        .bss'))
for label in ('mm_alloc_nr_fit:', 'mm_free_busy:',
              'mm_pin_add_ok:', 'mm_pin_sub:'):
    assert label in parts
(work/'real-mm-v1554.s').write_text(decls+constants+parts)

# Create the versioned VERIFY fixture from the previously accepted real-MM
# test, but make it exercise only the new VERIFY entry. A wrong dispatch to
# v1551 ARM goes to a hard failure, not to a shared successful stub.
original=(self/'daimos-dtfs-owned-scratch-real-mm-v1552.s').read_text()
assert original.count('pushj   17,dtfs_intent_owned_arm_v1552')==3
assert original.count('dtfs_intent_arm_v1551:\n')==1
assert original.count('dtfs_intent_verify_v1554:\n')==1
fixture=original.replace('pushj   17,dtfs_intent_owned_arm_v1552',
                         'pushj   17,dtfs_intent_owned_verify_v1554')
fixture=fixture.replace('dtfs_intent_arm_v1551:\n',
                        'verify_leaf_temp_v1554:\n',1)
fixture=fixture.replace('dtfs_intent_verify_v1554:\n',
                        'dtfs_intent_arm_v1551:\n',1)
fixture=fixture.replace('verify_leaf_temp_v1554:\n',
                        'dtfs_intent_verify_v1554:\n',1)
fixture=fixture.replace('_v1552','_v1554')
fixture=fixture.replace('dtfs_intent_owned_arm_v1554',
                        'dtfs_intent_owned_arm_v1552')
assert fixture.count('dtfs_intent_verify_v1554:\n')==1
assert fixture.count('pushj   17,dtfs_intent_owned_verify_v1554')==3
assert 'mm_is_pinned' in fixture
(work/'real-verify-fixture-v1554.s').write_text(fixture)

source=(repo/'system/kernel/fs/dtfs_intent_owned_arm_v1552.s').read_text()
mutants=(
    ('wrong-verify-dispatch',
     'movei   5,1                     ; verify already DIRTY',
     'setz    5,                      ; accidentally re-arm CLEAN'),
    ('verification-without-pin',
     'pushj   17,mm_pin',
     'setz    1,                      ; no physical MM pin'),
    ('verification-without-unpin',
     'pushj   17,mm_unpin',
     'setz    1,                      ; leaked physical pin'),
    ('verification-without-free',
     'pushj   17,mm_free',
     'setz    1,                      ; leaked MM extent'),
)
for name,old,new in mutants:
    assert source.count(old) in (1,2),(name,source.count(old))
    (work/('mutant-'+name+'-v1554.s')).write_text(source.replace(old,new,1))
print('v1554: real MM verify dispatch, two releases and shortage; '
      '%d actual-source mutations' % len(mutants))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 220000 --timeout 20 \
        --workdir "$work/run-$label" --name "dtfs-verify-mm-$label-v1554" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$work/real-verify-fixture-v1554.s" \
        "$source" "$work/real-mm-v1554.s" > "$work/$label.log" 2>&1
}

if ! run_case baseline "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_owned_arm_v1552.s"; then
    tail -70 "$work/baseline.log" >&2
    echo 'FAIL v1554: real-MM source-linked verify dispatch' >&2
    exit 1
fi
echo 'PASS v1554: actual MM pin/release twice via VERIFY, shortage refuses'

for mutation in wrong-verify-dispatch verification-without-pin \
    verification-without-unpin verification-without-free; do
    if run_case "$mutation" "$work/mutant-$mutation-v1554.s"; then
        echo "FAIL v1554: unsafe MM verification mutant accepted: $mutation" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutation.log" || {
        echo "FAIL v1554: MM mutant failed outside native oracle: $mutation" >&2
        tail -35 "$work/$mutation.log" >&2
        exit 1
    }
    echo "PASS v1554: rejected $mutation"
done
echo 'PASS v1554: shared MM scratch lifetime accepted for physical verify'
