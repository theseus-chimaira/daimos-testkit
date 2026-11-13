#!/bin/sh
# Both real source service gates on the same simulated physical controller.
# Exercise first-failure ordering, distinct HALT PCs, and owner retention.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-shared-root-backstore-v1546.XXXXXX")
if [ "${V1546_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$self" "$work" <<'PY'
from pathlib import Path
import sys

repo, tests, work = (Path(x) for x in sys.argv[1:])
fs = (repo / 'system/kernel/fs/d6fs_runtime.s').read_text()
adapter = (repo / 'system/kernel/storage/fs_backing.s').read_text()
swap = (repo / 'system/kernel/fs/fs_mres.s').read_text()
proc = (repo / 'system/kernel/proc/proc_storage_runtime_v30.s').read_text()

def part(text, start, end):
    assert text.count(start) == 1, (start, text.count(start))
    assert text.count(end) == 1, (end, text.count(end))
    return text[text.index(start):text.index(end)]

read = part(fs, 'd6fs_reader_get_block:\n',
            '        .globl  d6fs_reader_fcb\n')
restore = part(fs, 'd6fs_restore3:\n',
               '        .globl  d6fs_reader_commit_cache\n')
storage = part(swap, 'backstore_read:\n', 'blockset_tail_blocks:\n')
gate = proc[proc.index('kcore_root_fs_io_failure_v1538:\n'):]
assert read.count('pushj   17,kcore_root_fs_io_failure_v1538') == 1
assert storage.count('jrst    kcore_critical_device_lost_v1515') == 1
assert gate.count('halt    .') == 3
assert adapter.count('fs_backing_direct_read_jump:') == 1
golden = ('.text\n.globl d6fs_reader_get_block\n.globl backstore_read\n'
          '.globl blockset_runtime_service_call\n'
          '.globl kcore_root_fs_io_failure_v1538\n'
          '.globl kcore_critical_device_lost_v1515\n'
          '.globl kcore_critical_media_root_halt_v1515\n'
          '.globl kcore_critical_media_swap_halt_v1515\n'
          + read + restore + adapter + storage + gate)
(work / 'linked-v1546.s').write_text(golden)
fixture = (tests / 'daimos-shared-root-backstore-v1546.s').read_text()
settings = {
    'test_order_v1546': '0',
    'test_root_fail_v1546': '1',
    'test_swap_fail_v1546': '1',
    'test_mapper_fail_v1546': '0',
    'test_root_result_v1546': 'fs_block_workspace',
    'test_swap_result_v1546': '0',
    'test_root_calls_v1546': '1',
    'test_swap_calls_v1546': '1',
    'backstore_enabled': '1',
    'backstore_blocks_used': '0320',
    'test_owner_v1546': '0320',
    'device_region_map': '0,,010',
    'volume_data_blocks': '0',
    'root_selector_v1546': '0100000,,0200',
}
cases = (
    ('root-first-device', {}, 'root', 1),
    ('swap-first-device', {'test_order_v1546':'1'}, 'swap', 1),
    ('root-first-drum', {'root_selector_v1546':'0500000,,0200',
                         'device_region_map':'0400000,,010'}, 'root', 1),
    ('swap-first-drum', {'root_selector_v1546':'0500000,,0200',
                         'device_region_map':'0400000,,010',
                         'test_order_v1546':'1'}, 'swap', 1),
    ('root-first-volume', {'volume_data_blocks':'010'}, 'root', 1),
    ('swap-first-volume', {'volume_data_blocks':'010',
                           'test_order_v1546':'1'}, 'swap', 1),
    ('swap-mapper-fail', {'volume_data_blocks':'010',
                          'test_mapper_fail_v1546':'1',
                          'test_order_v1546':'1'}, 'swap', 1),
    ('swap-disabled-owned', {'backstore_enabled':'0',
                             'test_order_v1546':'1'}, 'swap', 1),
    ('root-ok-swap-fail', {'test_root_fail_v1546':'0'}, 'swap', 2),
    ('swap-ok-root-fail', {'test_order_v1546':'1',
                          'test_swap_fail_v1546':'0'}, 'root', 2),
    ('both-ok', {'test_root_fail_v1546':'0',
                 'test_swap_fail_v1546':'0',
                 'test_root_result_v1546':'fs_block_workspace'}, 'normal', 2),
    ('swap-inactive-unowned', {'test_order_v1546':'1',
                               'backstore_enabled':'0',
                               'backstore_blocks_used':'0',
                               'test_owner_v1546':'0',
                               'test_swap_result_v1546':'-1',
                               'test_root_fail_v1546':'0'}, 'normal', 2),
)
for name, changes, result, count in cases:
    values = dict(settings)
    values.update(changes)
    lines = fixture.splitlines(keepends=True)
    for label, value in values.items():
        prefix = label + ': .word '
        indices = [i for i,line in enumerate(lines) if line.startswith(prefix)]
        assert len(indices) == 1, (name,label,indices)
        lines[indices[0]] = prefix + value + '\n'
    (work / ('case-' + name + '-v1546.s')).write_text(''.join(lines))
    if count == 1:
        root_calls = 1 if values['test_order_v1546'] == '0' else 0
        swap_calls = 1 - root_calls
    else:
        root_calls = swap_calls = 1
    (work / ('check-' + name + '-v1546.txt')).write_text(
        '\n'.join((result,str(count),values['backstore_blocks_used'],
                   str(root_calls),str(swap_calls))) + '\n')

mutations = (
    ('swap-misroute-root',
     'movei   1,2\n        jrst    kcore_critical_device_lost_v1515',
     'movei   1,1\n        jrst    kcore_critical_device_lost_v1515',
     'swap-first-device'),
    ('root-misroute-swap',
     'kcore_root_fs_io_halt_v1538:\n        movei   1,1',
     'kcore_root_fs_io_halt_v1538:\n        movei   1,2',
     'root-first-device'),
    ('swap-ignores-owned',
     'skipn   backstore_blocks_used',
     'skipn   test_force_zero_v1546',
     'swap-disabled-owned'),
    ('swap-bypasses-mapper-failure',
     'jumpl   1,blockset_direct_tail_done',
     'jumpl   1,kret_neg1',
     'swap-mapper-fail'),
    ('root-bypasses-mount',
     'camn    1,2\n        jrst    kcore_root_fs_io_halt_v1538',
     'came    1,2\n        jrst    kcore_root_fs_io_halt_v1538',
     'root-first-device'),
)
for name, old, new, case in mutations:
    assert golden.count(old) == 1, (name, golden.count(old))
    (work / ('mutant-' + name + '-v1546.s')).write_text(
        golden.replace(old,new,1))
    (work / ('mutant-case-' + name + '.txt')).write_text(case)
print('v1546: source-linked shared-controller cases generated')
PY

run_case() {
    label=$1; case=$2; source=$3
    expected_kind=$(sed -n '1p' "$work/check-$case-v1546.txt")
    expected_owner=$(sed -n '3p' "$work/check-$case-v1546.txt")
    root_calls=$(sed -n '4p' "$work/check-$case-v1546.txt")
    swap_calls=$(sed -n '5p' "$work/check-$case-v1546.txt")
    exit_value=1
    if [ "$expected_kind" = normal ]; then exit_value=0; fi
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 180000 --timeout 15 \
        --workdir "$work/run-$label" --name "shared-$label-v1546" \
        --expect "__test_exit=$exit_value" \
        --expect "backstore_blocks_used=$expected_owner" \
        --expect "root_calls_v1546=$root_calls" \
        --expect "swap_calls_v1546=$swap_calls" \
        "$self/daimos-test-crt0-v1.s" \
        "$work/case-$case-v1546.s" "$source" \
        > "$work/$label.log" 2>&1
}

check_halt() {
    label=$1; expected=$2
    python3 - "$work/run-$label/shared-$label-v1546.report.txt" \
        "$work/run-$label/shared-$label-v1546.labels" "$expected" <<'PY'
from pathlib import Path
import re
import sys
report, labels = (Path(x).read_text() for x in sys.argv[1:3])
type = sys.argv[3]
halt = re.findall(r'HALT instruction, PC: ([0-7]{6})', report)
assert len(halt) == 1, halt
symbols = dict(re.findall(r'(?m)^(\S+)\s+([0-7]{6})\s*$', labels))
expected = symbols['kcore_critical_media_' + type + '_halt_v1515']
other = symbols['kcore_critical_media_' + ('swap' if type == 'root' else 'root') + '_halt_v1515']
assert halt[0] == expected and halt[0] != other, (halt,expected,other)
print('PASS v1546: exact ' + type + ' HALT PC=' + expected)
PY
}

for name in root-first-device swap-first-device root-first-drum \
    swap-first-drum root-first-volume swap-first-volume \
    swap-mapper-fail swap-disabled-owned \
    root-ok-swap-fail swap-ok-root-fail both-ok swap-inactive-unowned; do
    expected=$(sed -n '1p' "$work/check-$name-v1546.txt")
    if ! run_case "$name" "$name" "$work/linked-v1546.s"; then
        tail -45 "$work/$name.log" >&2; exit 1
    fi
    if [ "$expected" != normal ]; then check_halt "$name" "$expected"; fi
    echo "PASS v1546: $name"
done

for mutant in swap-misroute-root root-misroute-swap \
    swap-ignores-owned swap-bypasses-mapper-failure \
    root-bypasses-mount; do
    case=$(cat "$work/mutant-case-$mutant.txt")
    expected=$(sed -n '1p' "$work/check-$case-v1546.txt")
    if run_case "mutant-$mutant" "$case" \
        "$work/mutant-$mutant-v1546.s"; then
        if check_halt "mutant-$mutant" "$expected" >/dev/null 2>&1; then
            echo "FAIL v1546: accepted unsafe mutant $mutant" >&2
            exit 1
        fi
    fi
    echo "PASS v1546: rejected $mutant"
done
echo 'PASS v1546: shared ROOT/BACKSTORE owner-order native matrix'
