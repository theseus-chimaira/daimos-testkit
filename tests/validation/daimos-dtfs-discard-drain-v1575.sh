#!/bin/sh
# Native PDP-6 source-linked DTFS private provider drain and two mutants.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-discard-drain-v1575.XXXXXX")
trap 'if [ "${V1575_KEEP_WORK:-0}" != 1 ]; then rm -rf "$work"; else echo "v1575 source evidence: $work"; fi' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel/fs/dtfs_runtime.s" "$work" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
out = Path(sys.argv[2])
label = 'dtfs_discard_drain_v1575:\n'
assert source.count(label) == 1
leaf = label + source.split(label, 1)[1].split(
    '        .data\ndtfs_mres_vector:', 1)[0]
assert 'dtfs_dtc_read' not in leaf and 'dtfs_dtc_write' not in leaf
assert leaf.count('setzm   dtfs_cache_mount') == 1
assert leaf.count('pushj   17,bcache_invalidate_all') == 1
variants = (
    ('production', leaf),
    ('skip-cache', leaf.replace('setzm   dtfs_cache_mount',
                                'move    5,5', 1)),
    ('skip-bcache', leaf.replace('pushj   17,bcache_invalidate_all',
                                 'move    5,5', 1)),
)
for name, code in variants:
    (out / (name + '-v1575.s')).write_text(
        '.text\n.globl dtfs_discard_drain_v1575\n' + code)
print('PASS v1575: exact original provider drain, zero raw DTC operations')
PY

for name in production skip-cache skip-bcache; do
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 90000 --timeout 30 \
        --workdir "$work/run-$name" --name "dtfs-drain-$name-v1575" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-discard-drain-v1575.s" \
        "$work/$name-v1575.s" > "$work/$name.log" 2>&1; then
        if [ "$name" != production ]; then
            echo "FAIL v1575: unsafe $name mutation accepted" >&2
            exit 1
        fi
        echo 'PASS v1575: source-linked provider drain and cache invalidation'
    else
        if [ "$name" = production ]; then
            tail -65 "$work/$name.log" >&2
            exit 1
        fi
        grep -q '^FAIL: __test_exit:' "$work/$name.log" || {
            tail -55 "$work/$name.log" >&2
            exit 1
        }
        echo "PASS v1575: rejected source mutation $name"
    fi
done
