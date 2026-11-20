#!/bin/sh
# Native source-linked u-area diagnostic with PI-gated stale owner change.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-uarea-probe-pi-v1701.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mm="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
{
    printf '%s\n' '.text' '.globl mm_uarea_probe_v887'
    sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' "$mm" | sed '$d'
    sed -n '/^mm_uarea_probe_v887:$/,/^; Find a fitting free gap/p' \
        "$mm" | sed '$d'
} > "$work/base.s"
python3 - "$work/base.s" "$work/production.s" "$work/unsafe.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
anchor = '        move    4,mm_extents+1(1)\n'
assert s.count(anchor) == 1
mutator = '''        ; Another MM owner is published at this slot by a PI handler.
        skipn   inject_v1701
        jrst    probe_continue_v1701
        coni    0004,0
        trnn    0,000200
        jrst    probe_continue_v1701
        setzm   inject_v1701
        move    0,[013,,01004]
        movem   0,mm_extents+1(1)
        aos     injected_v1701
probe_continue_v1701:
'''
s = s.replace(anchor, mutator + anchor, 1)
Path(sys.argv[2]).write_text(s)
lock = '        cono    0004,000400\n'
assert s.count(lock) == 1
Path(sys.argv[3]).write_text(s.replace(
    lock, '        move    0,0  ; unsafe: PI remains globally enabled\n', 1))
PY
run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 180000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-uarea-probe-pi-v1701-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-uarea-probe-pi-v1701.s" "$source" \
        > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -40 "$work/production.log" >&2
    exit 1
}
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1701: stale MM diagnostic owner unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -40 "$work/unsafe.log" >&2
    exit 1
}
echo 'K01 v1701: native PDP-6 stable u-area pins/type/owner/missing, PI state and stale-owner mutant PASS'
