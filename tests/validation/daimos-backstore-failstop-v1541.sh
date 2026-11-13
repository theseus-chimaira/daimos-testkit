#!/bin/sh
# Actual fixed KCORE BACKSTORE transfer and v1515 terminal leaf, PDP-6.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-backstore-failstop-v1541.XXXXXX")
if [ "${V1541_KEEP_TEST:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
python3 - "$DAIMOS_REPO" "$self" "$work" <<'PY'
from pathlib import Path
import sys

repo, tests, work = (Path(s) for s in sys.argv[1:])
fs = (repo / 'system/kernel/fs/fs_mres.s').read_text()
proc = (repo / 'system/kernel/proc/proc_storage_runtime_v30.s').read_text()
start = 'backstore_read:\n'
end = 'blockset_tail_blocks:\n'
assert fs.count(start) == 1 and fs.count(end) == 1
body = fs[fs.index(start):fs.index(end)]
leaf = proc[proc.index('kcore_critical_device_lost_v1515:\n'):]
assert body.count('jumpe   1,blockset_direct_tail_return_v1541') == 1
assert body.count('skipn   backstore_enabled') == 1
assert body.count('skipn   backstore_blocks_used') == 1
assert body.count('movei   1,2') >= 1
assert body.count('jrst    kcore_critical_device_lost_v1515') == 1
assert leaf.count('halt    .') == 3

head = ('.text\n.globl backstore_read\n.globl backstore_write\n'
        '.globl kcore_critical_media_root_halt_v1515\n'
        '.globl kcore_critical_media_swap_halt_v1515\n'
        '.globl kcore_critical_media_bad_reason_v1515\n')
golden = head + body + leaf
(work / 'linked-v1541.s').write_text(golden)
mutations = (
    ('no-failstop', 'jrst    kcore_critical_device_lost_v1515',
     'popj    17,'),
    ('wrong-reason', 'movei   1,2\n        jrst    kcore_critical_device_lost_v1515',
     'movei   1,1\n        jrst    kcore_critical_device_lost_v1515'),
    ('ignore-enable', 'skipn   backstore_enabled',
     'skipn   test_force_enabled_v1541'),
    ('ignore-owners', 'skipn   backstore_blocks_used',
     'skipn   test_force_zero_v1541'),
    ('halt-success', 'jumpe   1,blockset_direct_tail_return_v1541',
     'jumpn   1,blockset_direct_tail_return_v1541'),
    ('miss-mapped-failure', 'jumpl   1,blockset_direct_tail_done',
     'jumpl   1,kret_neg1'),
)
for label, before, after in mutations:
    assert golden.count(before) == 1, ('nonunique', label)
    (work / ('mutant-' + label + '-v1541.s')).write_text(
        golden.replace(before, after, 1))

fixture = (tests / 'daimos-backstore-failstop-v1541.s').read_text()
settings = {
    'test_first_v1541': '0',
    'test_blocks_v1541': '1',
    'test_buf_v1541': 'transfer_buffer_v1541',
    'test_write_v1541': '0',
    'test_fail_at_v1541': '1',
    'test_expected_v1541': '-1',
    'test_expected_calls_v1541': '1',
    'backstore_enabled': '1',
    'backstore_blocks_used': '0',
    'device_region_map': '0,,010',
    'volume_data_blocks': '0',
    'backing_region_count': '4',
}
cases = (
    ('dsk-read-fail', {}, True),
    ('dsk-write-fail', {'test_write_v1541':'1'}, True),
    ('drm-read-fail', {'device_region_map':'0400000,,010'}, True),
    ('drm-write-fail', {'device_region_map':'0400000,,010', 'test_write_v1541':'1'}, True),
    ('second-block-fail', {'test_blocks_v1541':'2','test_fail_at_v1541':'2'}, True),
    ('mapper-missing', {'volume_data_blocks':'010'}, True),
    ('disabled-dsk-fail', {'backstore_enabled':'0'}, False),
    ('disabled-owned-fail', {'backstore_enabled':'0','backstore_blocks_used':'1'}, True),
    ('disabled-mapper-fail', {'backstore_enabled':'0','volume_data_blocks':'010','test_expected_calls_v1541':'0'}, False),
    ('dsk-read-ok', {'test_fail_at_v1541':'0','test_expected_v1541':'0'}, False),
    ('dsk-write-ok', {'test_fail_at_v1541':'0','test_write_v1541':'1','test_expected_v1541':'0'}, False),
    ('two-block-ok', {'test_fail_at_v1541':'0','test_blocks_v1541':'2','test_expected_v1541':'0','test_expected_calls_v1541':'2'}, False),
    ('zero-count', {'test_blocks_v1541':'0','test_expected_v1541':'0','test_expected_calls_v1541':'0'}, False),
    ('negative-first', {'test_first_v1541':'-1','test_expected_calls_v1541':'0'}, False),
    ('overflow-count', {'test_first_v1541':'3','test_blocks_v1541':'2','test_expected_calls_v1541':'0'}, False),
    ('null-buffer', {'test_buf_v1541':'0','test_expected_calls_v1541':'0'}, False),
    ('no-region', {'backing_region_count':'0','test_expected_calls_v1541':'0'}, False),
)
for name, overrides, fatal in cases:
    values = dict(settings)
    values.update(overrides)
    lines = fixture.splitlines(keepends=True)
    for label, value in values.items():
        prefix = label + ': .word '
        matches = [i for i,s in enumerate(lines) if s.startswith(prefix)]
        assert len(matches) == 1, (name,label,matches)
        i = matches[0]
        old = lines[i]
        suffix = ' ;'+old.split(';', 1)[1] if ';' in old else '\n'
        lines[i] = prefix + value + suffix
    (work / ('case-' + name + '-v1541.s')).write_text(''.join(lines))
print('v1541: %d real-source cases, %d unsafe mutations generated' %
      (len(cases), len(mutations)))
PY

run_case() {
    label=$1
    case_name=$2
    source=$3
    exitval=$4
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 150000 --timeout 15 \
        --workdir "$work/run-$label" --name "bstore-$label-v1541" \
        --expect "__test_exit=$exitval" \
        "$self/daimos-test-crt0-v1.s" \
        "$work/case-$case_name-v1541.s" "$source" \
        > "$work/$label.log" 2>&1
}

check_swap_halt() {
    label=$1
    python3 - "$work/run-$label/bstore-$label-v1541.report.txt" \
        "$work/run-$label/bstore-$label-v1541.labels" <<'PY'
from pathlib import Path
import re
import sys
report, labels = (Path(s).read_text() for s in sys.argv[1:])
match = re.search(r'HALT instruction, PC: ([0-7]{6})', report)
assert match, 'native PDP-6 not halted'
symbols = dict(re.findall(r'(?m)^(\S+)\s+([0-7]{6})\s*$', labels))
pc = match.group(1)
assert pc == symbols['kcore_critical_media_swap_halt_v1515'], (
    'wrong BACKSTORE HALT PC: ' + pc)
assert pc != symbols['kcore_critical_media_root_halt_v1515']
assert pc != symbols['kcore_critical_media_bad_reason_v1515']
print('v1541: matched BACKSTORE HALT PC ' + pc)
PY
}

for label in dsk-read-fail dsk-write-fail drm-read-fail \
    drm-write-fail second-block-fail mapper-missing disabled-owned-fail; do
    run_case "$label" "$label" "$work/linked-v1541.s" 1 || {
        tail -45 "$work/$label.log" >&2; exit 1;
    }
    check_swap_halt "$label"
    echo "PASS v1541: $label exact BACKSTORE HALT"
done
for label in disabled-dsk-fail disabled-mapper-fail dsk-read-ok \
    dsk-write-ok two-block-ok zero-count negative-first overflow-count \
    null-buffer no-region; do
    run_case "$label" "$label" "$work/linked-v1541.s" 0 || {
        tail -45 "$work/$label.log" >&2; exit 1;
    }
    echo "PASS v1541: $label no HALT"
done
for spec in no-failstop:dsk-read-fail wrong-reason:dsk-read-fail \
    ignore-enable:disabled-dsk-fail halt-success:dsk-read-ok \
    ignore-owners:disabled-owned-fail \
    miss-mapped-failure:mapper-missing; do
    mutant=${spec%%:*}
    case_name=${spec#*:}
    expect=1
    case "$case_name" in disabled-dsk-fail|dsk-read-ok) expect=0 ;; esac
    if run_case "mutant-$mutant" "$case_name" \
        "$work/mutant-$mutant-v1541.s" "$expect"; then
        if [ "$expect" = 1 ] && \
            ! check_swap_halt "mutant-$mutant" >/dev/null 2>&1; then
            echo "PASS v1541: rejected $mutant (incorrect HALT PC)"
            continue
        fi
        echo "FAIL v1541: accepted mutation $mutant" >&2
        exit 1
    fi
    echo "PASS v1541: rejected mutation $mutant"
done
echo 'PASS v1541: critical BACKSTORE I/O fail-stop and inactive/probe isolation'
