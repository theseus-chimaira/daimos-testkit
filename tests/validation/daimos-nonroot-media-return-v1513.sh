#!/bin/sh
# Native PDP-6 source-linked non-root media return, not controller-loss proof.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-nonroot-media-return-v1513.XXXXXX")
if [ "${V1513_KEEP_TEST:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

root, work = (Path(x) for x in sys.argv[1:])
d6 = (root / 'system/kernel/fs/d6fs_runtime.s').read_text()
start = 'd6fs_reader_get_block:\n'
end = '        .globl  d6fs_reader_fcb\n'
assert d6.count(start) == 1 and d6.count(end) == 1
block = d6[d6.index(start):d6.index(end)]
assert 'jumpn   1,d6fs_get_block_io_error_v1538' in block
assert block.index('jumpn   1,d6fs_get_block_io_error_v1538') < block.index('pushj   17,bcache_store')
assert 'd6fs_get_block_read_fail:\n        setz    1,' in block
restore = d6[d6.index('d6fs_restore3:\n'):d6.index('        .globl  d6fs_reader_commit_cache\n')]
assert restore.count('pop     17,012') == 1
fs = (root / 'system/kernel/storage/fs_backing.s').read_text()
first = fs.index('fs_backing_read:\n')
last = fs.index('; int fs_backing_write(', first)
bridge = fs[first:last]
assert 'jrst    (4)' in bridge and 'jumpe   4,kret_neg1' in bridge
proc = (root / 'system/kernel/proc/proc_storage_runtime_v30.s').read_text()
gate = proc[proc.index('kcore_root_fs_io_failure_v1538:\n'):]
assert 'kcore_critical_device_lost_v1515:' in gate
(work / 'linked-v1513.s').write_text(
    '.text\n.globl d6fs_reader_get_block\n.globl fs_backing_read\n' +
    block + restore + bridge + gate)
assert 'bcache_store' not in block[block.index('d6fs_get_block_read_fail:'):]

full = '.text\n.globl d6fs_reader_get_block\n.globl fs_backing_read\n' + block + restore + bridge + gate
for label, old, new in (
        ('negative-read', 'jumpn   1,d6fs_get_block_io_error_v1538',
         'jumpe   1,d6fs_get_block_io_error_v1538'),
        ('null-result', 'd6fs_get_block_read_fail:\n        setz    1,',
         'd6fs_get_block_read_fail:\n        seto    1,'),
        ('callback-return', '        jrst    (4)\n',
         '        jrst    kret_zero\n')):
    if full.count(old) != 1:
        raise AssertionError('v1513 changed source anchor: ' + label)
    (work / ('mutant-' + label + '-v1513.s')).write_text(
        full.replace(old, new, 1))
print('v1513: generated three source-linked negative mutants')
PY

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 100000 --timeout 15 \
    --workdir "$work/run" --name daimos-nonroot-media-return-v1513 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-nonroot-media-return-v1513.s" \
    "$work/linked-v1513.s" > "$work/run.log" 2>&1 || {
        tail -75 "$work/run.log" >&2
        exit 1
    }
echo 'PASS v1513: nonroot D6FS read failure, clean retry, root isolation'

for label in negative-read null-result callback-return; do
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 100000 --timeout 15 \
        --workdir "$work/run-$label" --name "nonroot-$label-v1513" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-nonroot-media-return-v1513.s" \
        "$work/mutant-$label-v1513.s" > "$work/$label.log" 2>&1; then
        echo "FAIL v1513: accepted broken $label source" >&2
        exit 1
    fi
    if ! grep -q 'FAIL: __test_exit:' "$work/$label.log"; then
        echo "FAIL v1513: mutant $label did not reach negative oracle" >&2
        tail -25 "$work/$label.log" >&2
        exit 1
    fi
    echo "PASS v1513: rejected $label source mutation"
done
