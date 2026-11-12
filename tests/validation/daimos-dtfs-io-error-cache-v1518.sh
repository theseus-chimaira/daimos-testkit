#!/bin/sh
# PDP-6 DTFS source-linked raw failure, shared directory and BCACHE.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-io-error-cache-v1518.XXXXXX")
if [ "${V1518_KEEP_TEST:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo, out = (Path(s) for s in sys.argv[1:])
dtfs = (repo / 'system/kernel/fs/dtfs_runtime.s').read_text()
first = dtfs.index('dtfs_dtc_read:\n')
last = dtfs.index('        .if DTFS_ENABLE_FOREIGN\n', first)
bridge = dtfs[first:last]
read_slot = 'dtfs_dtc_read_jump:\n        jrst    0'
write_slot = 'dtfs_dtc_write_jump:\n        jrst    0'
assert bridge.count(read_slot) == bridge.count(write_slot) == 1
bridge = bridge.replace(read_slot,
    'dtfs_dtc_read_jump:\n        jrst    test_raw_read_v1518')
bridge = bridge.replace(write_slot,
    'dtfs_dtc_write_jump:\n        jrst    test_raw_write_v1518')
# Use the actual native-only DTFS directory-loader branch and its
# original backing read, rather than modeling its cached mount decision.
native = dtfs.index('.else\n; Native-only build:')
start = dtfs.index('dtfs_load:\n', native)
end = dtfs.index('.endif\n', start)
load = dtfs[start:end]
assert load.count('camn    4,010') == 1
assert load.count('pushj   17,dtfs_dtc_read') == 1

cache = (repo / 'system/kernel/storage/bcache_pdp6.s').read_text()
assert cache.count('bcache_invalidate_all:\n') == 1
header = ('.text\n.globl dtfs_dtc_read\n.globl dtfs_dtc_write\n'
          '.globl dtfs_load\n.globl bcache_fetch\n'
          '.globl bcache_store\n.globl bcache_invalidate_all\n'
          '.globl bcache_state\n.globl bcache_workspace_tag\n')
# Full BCACHE source gives the test real clean tags and data copying.
source = header + bridge + load + '\n' + cache
(out / 'source-v1518.s').write_text(source)

# Each unsafe source edit is executed, not merely checked textually.
for name, old, new in (
        ('preserve-dir-read-error',
         'dtfs_dtc_read_failed_v1518:\n        ; Failed physical reads',
         'dtfs_dtc_read_failed_v1518:\n        jrst    dtfs_dtc_read_done\n        ; Failed physical reads'),
        ('skip-read-bcache-invalidation',
         'setzm   dtfs_cache_mount\n        pushj   17,bcache_invalidate_all',
         'setzm   dtfs_cache_mount\n        pushj   17,kret_zero'),
        ('preserve-dir-write-error',
         '        setzm   dtfs_cache_mount\n        push    17,1',
         '        jrst    dtfs_dtc_write_done_v1518\n        push    17,1'),
        ('skip-write-cache-invalidation',
         'dtfs_dtc_write:\n        ; Invalidate',
         'dtfs_dtc_write:\n        jrst    dtfs_dtc_write_jump\n        ; Invalidate')):
    if source.count(old) != 1:
        raise AssertionError('v1518 source mutation ambiguity: ' + name)
    (out / ('mutant-' + name + '-v1518.s')).write_text(
        source.replace(old, new, 1))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 250000 --timeout 15 \
        --workdir "$work/run-$label" --name "dtfs-$label-v1518" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-io-error-cache-v1518.s" \
        "$source" > "$work/$label.log" 2>&1
}

run_case baseline "$work/source-v1518.s" || {
    tail -65 "$work/baseline.log" >&2
    exit 1
}
echo 'PASS v1518: DTFS read/write errors invalidate cache and directory identity'
for name in preserve-dir-read-error skip-read-bcache-invalidation \
    preserve-dir-write-error skip-write-cache-invalidation; do
    if run_case "$name" "$work/mutant-$name-v1518.s"; then
        echo "FAIL v1518: unsafe $name accepted" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$name.log" || {
        echo "FAIL v1518: $name did not reach native failure oracle" >&2
        tail -28 "$work/$name.log" >&2
        exit 1
    }
    echo "PASS v1518: rejected $name source mutation"
done
