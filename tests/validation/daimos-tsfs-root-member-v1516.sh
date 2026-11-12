#!/bin/sh
# Actual TSFS provider source membership predicate and fail-closed mutants.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-tsfs-root-member-v1516.XXXXXX")
if [ "${V1516_KEEP_TEST:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo, work = (Path(x) for x in sys.argv[1:])
src = (repo / 'system/kernel/fs/tsfs_runtime.s').read_text()
first = src.index('tsfs_root_owns_dtc_unit_v1516:\n')
last = src.index('        .globl  bcache_reclaim\n', first)
body = src[first:last]
head = '.text\n.globl tsfs_root_owns_dtc_unit_v1516\n'
for key in ('lsh     3,-030', 'andi    3,0377',
            'caie    2,7', 'camle   2,vfs_mount_limit',
            'andi    3,0377\n        jumpe   3,tsfs_root_dtc_bad_v1516'):
    assert body.count(key) == 1, 'missing TSFS root guard ' + key
(work / 'root-helper-v1516.s').write_text(head + body)
for label, old, new in (
        ('lost-physical-mask', 'lsh     3,-030', 'lsh     3,-027'),
        ('no-provider', 'caie    2,7', 'caie    2,6'),
        ('skip-mount-limit', 'camle   2,vfs_mount_limit',
         'camle   2,[077]'),
        ('invalid-mask-accepted',
         'andi    3,0377\n        jumpe   3,tsfs_root_dtc_bad_v1516',
         'andi    3,0377\n        jumpe   3,tsfs_root_dtc_no_v1516')):
    assert body.count(old) == 1
    (work / ('mutant-' + label + '-v1516.s')).write_text(
        head + body.replace(old, new, 1))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 100000 --timeout 15 \
        --workdir "$work/run-$label" --name "tsfs-$label-v1516" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-tsfs-root-member-v1516.s" \
        "$source" > "$work/$label.log" 2>&1
}

run_case baseline "$work/root-helper-v1516.s" || {
    tail -65 "$work/baseline.log" >&2
    exit 1
}
echo 'PASS v1516: actual TSFS root mask disambiguates physical unit zero'
for label in lost-physical-mask no-provider skip-mount-limit invalid-mask-accepted; do
    if run_case "$label" "$work/mutant-$label-v1516.s"; then
        echo "FAIL v1516: accepted $label" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$label.log" || {
        echo "FAIL v1516: mutant $label did not execute negative oracle" >&2
        tail -25 "$work/$label.log" >&2
        exit 1
    }
    echo "PASS v1516: rejected $label source mutation"
done
