#!/bin/sh
# Native source-linked MM advisory pin lookup under PI exclusion.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-is-pinned-pi-v1711.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mm="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
{
    printf '%s\n' '.text' '.globl mm_is_pinned'
    sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' "$mm" | sed '$d'
    sed -n '/^mm_is_pinned:$/,/^; Read-only u-area extent ownership/p' \
        "$mm" | sed '$d'
} > "$work/base.s"
python3 - "$work/base.s" "$work/production.s" "$work/unsafe.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
anchor = '        move    2,mm_extents+1(1)\n'
assert s.count(anchor) == 1
mutation = '''        ; Simulate interrupt-side pin acquisition after base search.
        skipn   inject_v1711
        jrst    pin_lookup_continue_v1711
        coni    0004,0
        trnn    0,000200
        jrst    pin_lookup_continue_v1711
        setzm   inject_v1711
        move    0,[011,,02]
        movem   0,mm_extents+1(1)
        aos     injected_v1711
pin_lookup_continue_v1711:
'''
s = s.replace(anchor, mutation + anchor, 1)
Path(sys.argv[2]).write_text(s)
guard = '        cono    0004,000400\n'
assert s.count(guard) == 1
Path(sys.argv[3]).write_text(s.replace(
    guard, '        move    0,0  ; unsafe: PI remains enabled\n', 1))
PY
run()
{
    name=$1
    src=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 100000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-is-pinned-v1711-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-is-pinned-pi-v1711.s" "$src" \
        > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -50 "$work/production.log" >&2
    exit 1
}
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1711: stale advisory pin lookup unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -50 "$work/unsafe.log" >&2
    exit 1
}
echo 'K01 v1711: native PDP-6 atomic advisory pin lookup, missing extent, PI state and mutant PASS'
