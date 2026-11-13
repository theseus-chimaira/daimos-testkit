#!/bin/sh
# Execute the actual v1538 KCORE gate and D6FS read/write error paths.
# The low-level error oracle models exhausted driver retries; this test
# does not claim a full-guest controller detach, which is separate.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-root-io-failstop-v1538.XXXXXX")
if [ "${V1538_KEEP_TEST:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" "$self" <<'PY'
from pathlib import Path
import sys

repo, work, tests = (Path(s) for s in sys.argv[1:])
runtime = (repo / 'system/kernel/fs/d6fs_runtime.s').read_text()
backing = (repo / 'system/kernel/storage/fs_backing.s').read_text()
proc = (repo / 'system/kernel/proc/proc_storage_runtime_v30.s').read_text()

def extract(text, first, last):
    assert text.count(first) == 1 and text.count(last) == 1, (first, last)
    return text[text.index(first):text.index(last)]

read = extract(runtime, 'd6fs_reader_get_block:\n',
               '        .globl  d6fs_reader_fcb\n')
restore = extract(runtime, 'd6fs_restore3:\n',
                  '        .globl  d6fs_reader_commit_cache\n')
write = extract(runtime, 'd6fs_reader_commit_cache:\n',
                '        .globl  d6fs_reader_write_block\n')
bridge = extract(backing, 'fs_backing_read:\n',
                 '; Root-storage bridge used while the boot root')
gate = proc[proc.index('kcore_root_fs_io_failure_v1538:\n'):]
assert gate.count('halt    .') == 3
assert read.count('jumpn   1,d6fs_get_block_io_error_v1538') == 1
assert write.count('jumpn   1,d6fs_reader_commit_io_error_v1538') == 1
assert read.count('pushj   17,kcore_root_fs_io_failure_v1538') == 1
assert write.count('pushj   17,kcore_root_fs_io_failure_v1538') == 1
assert gate.count('camn    1,2') == 1
src = ('.text\n.globl d6fs_reader_get_block\n'
       '.globl d6fs_reader_commit_cache\n'
       '.globl kcore_critical_media_root_halt_v1515\n'
       '.globl kcore_critical_media_swap_halt_v1515\n'
       + read + restore + write + bridge + gate)
(work / 'linked-v1538.s').write_text(src)

mutations = (
    ('no-read-gate', 'jumpn   1,d6fs_get_block_io_error_v1538',
     'jumpn   1,d6fs_get_block_read_fail'),
    ('no-write-gate', 'jumpn   1,d6fs_reader_commit_io_error_v1538',
     'jumpn   1,d6fs_reader_commit_fail_saved'),
    ('wrong-read-owner', 'move    2,1(010)\n        andi    2,077',
     'movei   2,2\n        andi    2,077'),
    ('ignore-selected-root', 'camn    1,2\n        jrst    kcore_root_fs_io_halt_v1538',
     'camn    1,1\n        jrst    kcore_root_fs_io_halt_v1538'),
    ('wrong-halt-reason', 'kcore_root_fs_io_halt_v1538:\n        movei   1,1',
     'kcore_root_fs_io_halt_v1538:\n        movei   1,2'),
)
for label, old, new in mutations:
    assert src.count(old) == 1, 'ambiguous source mutant: ' + label
    (work / ('mutant-' + label + '-v1538.s')).write_text(
        src.replace(old, new, 1))

fixture = (tests / 'daimos-root-io-failstop-v1538.s').read_text()
changes = {
    'test_reader_v1538: .word root_reader_v1538': 'reader',
    'test_block_v1538: .word 5': 'block',
    'test_write_v1538: .word 0': 'write',
    'test_io_failed_v1538: .word 1': 'failed',
    'test_expected_v1538: .word 0': 'result',
    'test_stores_v1538: .word 0': 'stores',
    'test_io_calls_v1538: .word 1': 'calls',
    'vfs_namespace_root: .word 060101000000': 'root',
}

cases = (
    ('root-read', dict(), True),
    ('root-write', dict(write='1', result='-1'), True),
    ('secondary-read', dict(reader='secondary_reader_v1538'), False),
    ('secondary-write', dict(reader='secondary_reader_v1538', write='1', result='-1'), False),
    ('unmounted-read', dict(root='0'), False),
    ('other-root-read', dict(root='070101000000'), False),
    ('invalid-reader-mount', dict(reader='unmounted_reader_v1538'), False),
    ('invalid-block', dict(block='0100', calls='0'), False),
    ('root-read-success', dict(failed='0', result='fs_block_workspace', stores='1'), False),
    ('root-write-success', dict(write='1', failed='0', stores='1'), False),
    ('secondary-read-success', dict(reader='secondary_reader_v1538', failed='0', result='fs_block_workspace', stores='1'), False),
)
defaults = {'reader':'root_reader_v1538', 'block':'5', 'write':'0',
            'failed':'1','result':'0','stores':'0','calls':'1',
            'root':'060101000000'}
for label, opts, fatal in cases:
    vals = dict(defaults)
    vals.update(opts)
    case = fixture
    for template, field in changes.items():
        assert case.count(template) == 1
        head = template.split(': .word')[0]
        case = case.replace(template, head + ': .word ' + vals[field])
    (work / ('case-' + label + '-v1538.s')).write_text(case)
print('v1538 D6FS: source, eleven cases, five mutations PASS')
PY

run_case() {
    label=$1
    case_name=$2
    source=$3
    expect=$4
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 100000 --timeout 15 \
        --workdir "$work/run-$label" --name "rootio-$label-v1538" \
        --expect "__test_exit=$expect" \
        "$self/daimos-test-crt0-v1.s" \
        "$work/case-$case_name-v1538.s" "$source" \
        > "$work/$label.log" 2>&1
}

check_root_halt() {
    label=$1
    python3 - "$work/run-$label/rootio-$label-v1538.report.txt" \
        "$work/run-$label/rootio-$label-v1538.labels" <<'PY'
from pathlib import Path
import re
import sys
report, labels = (Path(s).read_text() for s in sys.argv[1:])
match = re.search(r'HALT instruction, PC: ([0-7]{6})', report)
assert match, 'missing real PDP-6 HALT'
symbols = dict(re.findall(r'(?m)^(\S+)\s+([0-7]{6})\s*$', labels))
pc = match.group(1)
assert pc == symbols['kcore_critical_media_root_halt_v1515'], (
    'wrong root HALT PC: ' + pc)
assert pc != symbols['kcore_critical_media_swap_halt_v1515']
print('v1538 D6FS: matched root HALT PC ' + pc)
PY
}

for label in root-read root-write; do
    run_case "$label" "$label" "$work/linked-v1538.s" 1 || {
        tail -65 "$work/$label.log" >&2; exit 1;
    }
    check_root_halt "$label"
    echo "PASS v1538: $label real root HALT"
done
for label in secondary-read secondary-write unmounted-read \
    other-root-read invalid-reader-mount invalid-block \
    root-read-success root-write-success secondary-read-success; do
    run_case "$label" "$label" "$work/linked-v1538.s" 0 || {
        tail -65 "$work/$label.log" >&2; exit 1;
    }
    echo "PASS v1538: $label never HALTs"
done

for spec in no-read-gate:root-read no-write-gate:root-write \
    wrong-read-owner:root-read ignore-selected-root:secondary-read \
    wrong-halt-reason:root-read; do
    mutant=${spec%%:*}; case_name=${spec#*:}
    expect=1
    if [ "$case_name" = secondary-read ]; then expect=0; fi
    if run_case "mutant-$mutant" "$case_name" \
        "$work/mutant-$mutant-v1538.s" "$expect"; then
        if [ "$expect" = 1 ] && \
            ! check_root_halt "mutant-$mutant" >/dev/null 2>&1; then
            echo "PASS v1538: rejected $mutant (wrong HALT PC)"
            continue
        fi
        echo "FAIL v1538: accepted source mutant $mutant" >&2
        exit 1
    fi
    echo "PASS v1538: rejected source mutant $mutant"
done
echo 'PASS v1538: D6FS root fail-stop/secondary isolation native matrix'
