#!/bin/sh
# Source-linked PDP-6 qualification of v1537 trusted TSFS loss routing.
# This does not simulate or certify an authoritative physical loss event.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-tsfs-confirmed-loss-v1537.XXXXXX")
if [ "${V1537_KEEP_TEST:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" "$self" <<'PY'
from pathlib import Path
import sys

repo, work, tests = (Path(s) for s in sys.argv[1:])
tsfs = (repo / 'system/kernel/fs/tsfs_runtime.s').read_text()
first = tsfs.index('tsfs_root_owns_dtc_unit_v1516:\n')
# Stop after this specific trusted dispatcher. Later provider additions
# must not silently become test dependencies or be linked by accident.
last = tsfs.index('tsfs_confirmed_root_member_loss_v1537:\n', first)
last = tsfs.index('        jrst    kcore_critical_device_lost_v1515\n', last)
last += len('        jrst    kcore_critical_device_lost_v1515\n')
body = tsfs[first:last]
leaf = (repo / 'system/kernel/proc/proc_storage_runtime_v30.s').read_text()
leaf = leaf[leaf.index('kcore_critical_device_lost_v1515:\n'):]
head = ('.text\n.globl tsfs_root_owns_dtc_unit_v1516\n'
        '.globl tsfs_confirmed_root_member_loss_v1537\n'
        '.globl kcore_critical_media_root_halt_v1515\n'
        '.globl kcore_critical_media_swap_halt_v1515\n')

for text in ('pushj   17,tsfs_root_owns_dtc_unit_v1516',
             'caie    1,1', 'movei   1,1',
             'jrst    kcore_critical_device_lost_v1515'):
    assert body.count(text) >= 1, 'source changed: ' + text
assert body.count('tsfs_confirmed_root_member_loss_v1537:') == 1
assert leaf.count('halt    .') == 3
(work / 'source-v1537.s').write_text(head + body + leaf)

mutations = (
    ('no-owner-query', 'pushj   17,tsfs_root_owns_dtc_unit_v1516',
     'movei   1,1'),
    ('wrong-member', 'caie    1,1\n        popj    17,',
     'caie    1,0\n        popj    17,'),
    ('no-halt-dispatch', 'jrst    kcore_critical_device_lost_v1515',
     'popj    17,'),
    ('wrong-reason', 'movei   1,1                     ; confirmed boot-root loss',
     'movei   1,2                     ; wrong BACKSTORE reason'),
)
for label, old, new in mutations:
    assert body.count(old) == 1, 'nonunique mutation anchor: ' + label
    changed = body.replace(old, new, 1)
    (work / ('mutant-' + label + '-v1537.s')).write_text(
        head + changed + leaf)

fixture = (tests / 'daimos-tsfs-confirmed-loss-v1537.s').read_text()
assert fixture.count('test_unit_v1537: .word 0') == 1
assert fixture.count('test_mask_v1537: .word 041') == 1
assert fixture.count('test_expected_v1537: .word 0') == 1
assert fixture.count('vfs_namespace_root: .word 070401000000') == 1
assert fixture.count('vfs_mount_limit: .word 6') == 1

# mode, physical unit, selected root member mask, provider/root mount,
# published capacity, expected return for nonfatal cases, fatal flag.
cases = (
    ('root0', 0, 0o41, '070401000000', 6, 0, True),
    ('root5', 5, 0o41, '070401000000', 6, 0, True),
    ('unrelated1', 1, 0o41, '070401000000', 6, 0, False),
    ('unrelated7', 7, 0o41, '070401000000', 6, 0, False),
    ('disk-root', 0, 0o41, '060401000000', 6, 0, False),
    ('invalid-unit', 8, 0o41, '070401000000', 6, -1, False),
    ('invalid-root', 0, 0o41, '070701000000', 6, -1, False),
    ('missing-mask', 0, 0, '070401000000', 6, -1, False),
)
for label, unit, mask, root, cap, expected, fatal in cases:
    text = fixture.replace('test_unit_v1537: .word 0',
                           'test_unit_v1537: .word %o' % unit)
    text = text.replace('test_mask_v1537: .word 041',
                        'test_mask_v1537: .word %o' % mask)
    text = text.replace('test_expected_v1537: .word 0',
                        'test_expected_v1537: .word %s' % expected)
    text = text.replace('vfs_namespace_root: .word 070401000000',
                        'vfs_namespace_root: .word ' + root)
    text = text.replace('vfs_mount_limit: .word 6',
                        'vfs_mount_limit: .word %o' % cap)
    (work / ('case-' + label + '-v1537.s')).write_text(text)
print('v1537: source extraction, eight cases and four mutations PASS')
PY

run_case() {
    label=$1
    testname=$2
    source=$3
    expected=$4
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 100000 --timeout 15 \
        --workdir "$work/run-$label" --name "critical-$label-v1537" \
        --expect "__test_exit=$expected" \
        "$self/daimos-test-crt0-v1.s" \
        "$work/case-$testname-v1537.s" "$source" > "$work/$label.log" 2>&1
}

check_root_halt() {
    label=$1
    python3 - "$work/run-$label/critical-$label-v1537.report.txt" \
        "$work/run-$label/critical-$label-v1537.labels" <<'PY'
from pathlib import Path
import re
import sys
report, labels = (Path(s).read_text() for s in sys.argv[1:])
match = re.search(r'HALT instruction, PC: ([0-7]{6})', report)
assert match, 'not a real PDP-6 HALT'
symbols = dict(re.findall(r'(?m)^(\S+)\s+([0-7]{6})\s*$', labels))
pc = match.group(1)
assert pc == symbols['kcore_critical_media_root_halt_v1515'], (
    'fatal reason PC is not boot-root HALT: ' + pc)
assert pc != symbols['kcore_critical_media_swap_halt_v1515']
assert int(pc, 8) >= 0o1000
print('v1537: exact physical root HALT PC = ' + pc)
PY
}

for label in root0 root5; do
    run_case "$label" "$label" "$work/source-v1537.s" 1 || {
        tail -60 "$work/$label.log" >&2; exit 1;
    }
    check_root_halt "$label"
    echo "PASS v1537: confirmed member $label reaches real root HALT"
done
for label in unrelated1 unrelated7 disk-root invalid-unit invalid-root missing-mask; do
    run_case "$label" "$label" "$work/source-v1537.s" 0 || {
        tail -60 "$work/$label.log" >&2; exit 1;
    }
    echo "PASS v1537: $label does not HALT"
done

# A mutant must fail the complete native oracle, not only match text.
for spec in no-owner-query:unrelated1 wrong-member:unrelated1 \
    no-halt-dispatch:root0 wrong-reason:root0; do
    mutant=${spec%%:*}
    case_name=${spec#*:}
    expect=0
    if [ "$case_name" = root0 ]; then expect=1; fi
    if run_case "mutant-$mutant" "$case_name" \
        "$work/mutant-$mutant-v1537.s" "$expect"; then
        if [ "$case_name" = root0 ] && \
            ! check_root_halt "mutant-$mutant" >/dev/null 2>&1; then
            echo "PASS v1537: rejected $mutant (wrong HALT PC)"
            continue
        fi
        echo "FAIL v1537: accepted mutant $mutant" >&2
        exit 1
    fi
    echo "PASS v1537: rejected $mutant (native oracle)"
done

echo 'PASS v1537: TSFS confirmed-event root ownership routing, not loss sensing'
