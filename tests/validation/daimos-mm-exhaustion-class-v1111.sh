#!/bin/sh
# v1111: distinguish real PDP-6 allocator shortage/fragmentation/slots.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-mm-exhaustion-class-v1111.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1111: $work"; fi' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" "$work" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
work = Path(sys.argv[2])

def leaf(first, last):
    assert source.count(first) == 1 and source.count(last) == 1
    return first + source.split(first, 1)[1].split(last, 1)[0]

header = ('.text\n.globl mm_alloc_aligned_noreclaim\n'
          '.globl mm_extent_insert\n.globl mm_find_fit\n')
body = (leaf('mm_extent_insert:\n', '\n; AC1=base.') +
        leaf('mm_find_fit:\n', '\n; int mm_alloc_aligned_noreclaim') +
        leaf('mm_alloc_aligned_noreclaim:\n', '\n; Move one process extent'))
assert '        movni   1,2\n' in body
assert 'mm_alloc_nr_descriptors:\n        movni   1,3\n' in body
(work / 'leaf.s').write_text(header + body)
for name, old, new in (
    ('fragment', '        movni   1,2\n', '        seto    1,\n'),
    ('descriptors', 'mm_alloc_nr_descriptors:\n        movni   1,3\n',
     'mm_alloc_nr_descriptors:\n        seto    1,\n'),
):
    assert body.count(old) == 1
    (work / ('unsafe-' + name + '.s')).write_text(
        header + body.replace(old, new, 1))
PY
run_case() {
    name=$1
    leaf=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 80000 --timeout 20 \
        --workdir "$work/run-$name" --name "mm-exhaustion-v1111-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$leaf" "$self/daimos-mm-exhaustion-class-v1111.s" \
        > "$work/log-$name" 2>&1
}
run_case positive "$work/leaf.s" || {
    tail -60 "$work/log-positive" >&2; exit 1;
}
for name in fragment descriptors; do
    if run_case "unsafe-$name" "$work/unsafe-$name.s"; then
        echo "v1111: unsafe $name error collapse passed" >&2
        exit 1
    fi
done
echo 'v1111: real PDP-6 MM -1/-2/-3, descriptor recovery, two mutants rejected PASS'
