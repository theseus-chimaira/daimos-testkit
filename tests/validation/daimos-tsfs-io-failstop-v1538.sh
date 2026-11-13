#!/bin/sh
# Actual TSFS root/secondary I/O error discrimination on the PDP-6 CPU.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-tsfs-io-failstop-v1538.XXXXXX")
if [ "${V1538_KEEP_TSFS:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" "$self" <<'PY'
from pathlib import Path
import sys

repo, work, tests = (Path(s) for s in sys.argv[1:])
src = (repo / 'system/kernel/fs/tsfs_runtime.s').read_text()
proc = (repo / 'system/kernel/proc/proc_storage_runtime_v30.s').read_text()
table = src[src.index('tsfs_file_record:\n'):
            src.index('; kword_t *tsfs_node_record(', src.index('tsfs_file_record:\n'))]
data = src[src.index('tsfs_read_words:\n'):src.index('tsfs_mount_set:\n')]
gate = proc[proc.index('kcore_root_fs_io_failure_v1538:\n'):]
assert table.count('pushj   17,kcore_root_fs_io_failure_v1538') == 1
assert data.count('pushj   17,kcore_root_fs_io_failure_v1538') == 1
assert data.count('jumpn   1,tsfs_read_words_io_error_v1538') == 2
assert gate.count('halt    .') == 3
header = ('.text\n.globl tsfs_file_record\n.globl tsfs_read_words\n'
          '.equ TSFS_EXT_BLOCK,1\n.equ TSFS_RESTART_WORDS,0400\n'
          '.equ TSFS_DECODE_OWNER,011\n'
          '.globl kcore_critical_media_root_halt_v1515\n'
          '.globl kcore_critical_media_swap_halt_v1515\n')
linked = header + table + data + gate
(work / 'linked-v1538.s').write_text(linked)
mutations = (
    ('no-table-owner', 'move    2,011\n        pushj   17,kcore_root_fs_io_failure_v1538',
     'move    2,011\n        pushj   17,test_no_halt_v1538'),
    ('wrong-table-owner', 'move    2,011\n        pushj   17,kcore_root_fs_io_failure_v1538',
     'movei   2,2\n        pushj   17,kcore_root_fs_io_failure_v1538'),
    ('no-stored-gate', 'jumpn   1,tsfs_read_words_io_error_v1538',
     'jumpn   1,tsfs_read_words_fail'),
    ('no-root-classification', 'camn    1,2\n        jrst    kcore_root_fs_io_halt_v1538',
     'camn    1,1\n        jrst    kcore_root_fs_io_halt_v1538'),
)
for label, old, new in mutations:
    n = linked.count(old)
    assert (n == 1 or (label == 'no-stored-gate' and n == 2)), (label,n)
    changed = linked.replace(old, new, 1)
    if label == 'no-table-owner':
        changed += '\ntest_no_halt_v1538:\n        seto 1,\n        popj 17,\n'
    (work / ('mutant-' + label + '-v1538.s')).write_text(changed)

fixture = (tests / 'daimos-tsfs-io-failstop-v1538.s').read_text()
defaults = {
    'root': '070101000000', 'vnode': '070102000001',
    'mode': '0', 'index': '1', 'count': '1', 'fail': '4',
    'extent': '0', 'expected': '-1', 'io': '1',
}
anchors = {
    'root': 'vfs_namespace_root: .word ',
    'vnode': 'test_vnode_v1538: .word ',
    'mode': 'test_mode_v1538: .word ',
    'index': 'test_index_v1538: .word ',
    'count': 'test_count_v1538: .word ',
    'fail': 'test_fail_block_v1538: .word ',
    'extent': 'test_extent_v1538: .word ',
    'expected': 'test_expected_v1538: .word ',
    'io': 'test_expected_io_v1538: .word ',
}
cases = (
    ('root-metadata', {}, True),
    ('secondary-metadata', {'vnode':'070202000001'}, False),
    ('unmounted-metadata', {'root':'0'}, False),
    ('other-root-metadata', {'root':'060101000000'}, False),
    # The low-level record helper returns HRROI 1,1 for invalid indices,
    # which is a negative 36-bit sentinel, not arithmetic -1.
    ('invalid-index', {'index':'2','expected':'0777777000001','io':'0'}, False),
    ('root-metadata-success', {'fail':'077','expected':'fs_block_workspace+010'}, False),
    ('root-stored-data', {'mode':'1','fail':'010','io':'2'}, True),
    ('secondary-stored-data', {'mode':'1','vnode':'070202000001','fail':'010','io':'2','expected':'0777777000001'}, False),
    ('root-block-data', {'mode':'1','extent':'1','fail':'010','io':'2'}, True),
    ('secondary-block-data', {'mode':'1','vnode':'070202000001','extent':'1','fail':'010','io':'2','expected':'0777777000001'}, False),
    ('root-stored-success', {'mode':'1','fail':'077','expected':'1','io':'2'}, False),
    ('root-zero-length', {'mode':'1','count':'0','expected':'0','io':'0'}, False),
)
for label, changes, fatal in cases:
    vals = dict(defaults)
    vals.update(changes)
    lines = fixture.splitlines(keepends=True)
    for name, prefix in anchors.items():
        matching = [i for i,s in enumerate(lines) if s.startswith(prefix)]
        assert len(matching) == 1, (name, matching)
        i = matching[0]
        # Preserve comments in fixture by keeping original suffix after ;.
        suffix = lines[i].split(';', 1)
        comment = ' ;' + suffix[1] if len(suffix) > 1 else '\n'
        lines[i] = prefix + vals[name] + comment
    (work / ('case-' + label + '-v1538.s')).write_text(''.join(lines))
print('v1538 TSFS: source-linked metadata/data cases and mutants prepared')
PY

run_case() {
    label=$1; testname=$2; source=$3; expect=$4
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 100000 --timeout 15 \
        --workdir "$work/run-$label" --name "tsfsio-$label-v1538" \
        --expect "__test_exit=$expect" \
        "$self/daimos-test-crt0-v1.s" \
        "$work/case-$testname-v1538.s" "$source" \
        > "$work/$label.log" 2>&1
}
check_root_halt() {
    label=$1
    python3 - "$work/run-$label/tsfsio-$label-v1538.report.txt" \
        "$work/run-$label/tsfsio-$label-v1538.labels" <<'PY'
from pathlib import Path
import re
import sys
report, labels = (Path(s).read_text() for s in sys.argv[1:])
halt = re.search(r'HALT instruction, PC: ([0-7]{6})', report)
assert halt is not None, 'no native HALT'
syms = dict(re.findall(r'(?m)^(\S+)\s+([0-7]{6})\s*$', labels))
pc = halt.group(1)
assert pc == syms['kcore_critical_media_root_halt_v1515']
assert pc != syms['kcore_critical_media_swap_halt_v1515']
print('v1538 TSFS: root HALT PC=' + pc)
PY
}

for label in root-metadata root-stored-data root-block-data; do
    run_case "$label" "$label" "$work/linked-v1538.s" 1 || {
        tail -50 "$work/$label.log" >&2; exit 1;
    }
    check_root_halt "$label"
    echo "PASS v1538 TSFS: $label"
done
for label in secondary-metadata unmounted-metadata other-root-metadata \
    invalid-index root-metadata-success secondary-stored-data \
    secondary-block-data root-stored-success root-zero-length; do
    run_case "$label" "$label" "$work/linked-v1538.s" 0 || {
        tail -50 "$work/$label.log" >&2; exit 1;
    }
    echo "PASS v1538 TSFS: $label nonfatal"
done
for spec in no-table-owner:root-metadata wrong-table-owner:root-metadata \
    no-stored-gate:root-stored-data no-root-classification:secondary-metadata; do
    mutant=${spec%%:*}; testname=${spec#*:}; expect=1
    if [ "$testname" = secondary-metadata ]; then expect=0; fi
    if run_case "mutant-$mutant" "$testname" \
        "$work/mutant-$mutant-v1538.s" "$expect"; then
        echo "FAIL v1538 TSFS: accepted mutant $mutant" >&2
        exit 1
    fi
    echo "PASS v1538 TSFS: rejected $mutant"
done
echo 'PASS v1538: TSFS selected-root fail-stop and auxiliary isolation'
