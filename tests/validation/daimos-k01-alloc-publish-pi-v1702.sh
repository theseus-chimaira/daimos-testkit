#!/bin/sh
# Actual MM find-fit and descriptor insert must be one PI-atomic action.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-alloc-publish-pi-v1702.XXXXXX")
if [ "${K01_KEEP_WORK:-0}" = 1 ]; then
    echo "K01 v1702 work: $work"
else
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mm="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
{
    printf '%s\n' '.text' '.globl mm_alloc_aligned_noreclaim' \
        '.globl mm_extent_insert'
    sed -n '/^mm_extent_insert:$/,/^; AC1=base\. Return/p' "$mm" | sed '$d'
    sed -n '/^mm_find_fit:$/,/^; int mm_alloc_aligned_noreclaim/p' "$mm" | sed '$d'
    sed -n '/^mm_alloc_aligned_noreclaim:$/,/^; Move one process extent upward/p' \
        "$mm" | sed '$d'
} > "$work/base.s"
python3 - "$work/base.s" "$work/production.s" \
    "$work/unsafe-pi.s" "$work/unsafe-frame.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
old = 'mm_extent_insert:\n'
assert s.count(old) == 1
mutator = '''mm_extent_insert:
        ; At exactly this boundary, model another PI caller inserting
        ; a physical owner into the previously selected free gap.
        skipn   inject_v1702
        jrst    insert_normal_v1702
        coni    0004,0
        trnn    0,000200
        jrst    insert_normal_v1702
        move    0,[02000,,010000]
        movem   0,mm_extents
        move    0,[01,,02]
        movem   0,mm_extents+1
        aos     mm_extent_count
        aos     injected_v1702
insert_normal_v1702:
'''
s = s.replace(old, mutator, 1)
Path(sys.argv[2]).write_text(s)
lock = '        cono    0004,000400\n'
assert s.count(lock) == 1
Path(sys.argv[3]).write_text(s.replace(
    lock, '        move    0,0  ; unsafe: global PI left enabled\n', 1))
frame = '        movem   1,-011(17)             ; previous global PI state\n'
assert s.count(frame) == 1
Path(sys.argv[4]).write_text(s.replace(
    frame, '        movem   1,-2(17)  ; unsafe: overwrite saved AC16\n', 1))
PY
run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 200000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-alloc-publish-pi-v1702-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-alloc-publish-pi-v1702.s" "$source" \
        > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -55 "$work/production.log" >&2
    exit 1
}
for name in unsafe-pi unsafe-frame; do
    if run "$name" "$work/$name.s"; then
        echo "K01 v1702: $name mutation unexpectedly passed" >&2
        exit 1
    fi
    grep -q '^FAIL:' "$work/$name.log" || {
        tail -55 "$work/$name.log" >&2
        exit 1
    }
done
echo 'K01 v1702: native PDP-6 atomic fit/insert, typed refusals, AC16, nested PI and two mutants PASS'
