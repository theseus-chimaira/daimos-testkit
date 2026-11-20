#!/bin/sh
# Source-linked real MM free/delete and simulated pin at the delete edge.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-mm-free-pi-v1697.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mm="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
{
    printf '%s\n' '.text' '.globl mm_free'
    sed -n '/^mm_delete:$/,/^; int mm_extent_insert/p' "$mm" | sed '$d'
    sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' "$mm" | sed '$d'
    sed -n '/^mm_free:$/,/^; int mm_process_transfer_pinned/p' "$mm" | sed '$d'
} > "$work/base.s"
python3 - "$work/base.s" "$work/production.s" "$work/unsafe.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
anchor = 'mm_delete:\n'
assert s.count(anchor) == 1
inject = '''mm_delete:
        ; Model a pinning PI immediately after the free's pin check.
        skipn   inject_at_delete_v1697
        jrst    mm_delete_body_v1697
        skipn   pi_depth_v1697
        jrst    mm_delete_inject_v1697
        jrst    mm_delete_body_v1697
mm_delete_inject_v1697:
        move    0,[011,,01]
        movem   0,mm_extents+1
        aos     injected_delete_v1697
mm_delete_body_v1697:
'''
s = s.replace(anchor, inject, 1)
Path(sys.argv[2]).write_text(s)
old = '        pushj   17,mach_pi_disable\n'
assert s.count(old) == 1
Path(sys.argv[3]).write_text(s.replace(old,
    '        movei   1,0200  ; unsafe: PI not disabled\n', 1))
PY
run()
{
    name=$1
    leaf=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 180000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-mm-free-pi-v1697-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-mm-free-pi-v1697.s" "$leaf" > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -40 "$work/production.log" >&2
    exit 1
}
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1697: unprotected MM free and pin mutation unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -40 "$work/unsafe.log" >&2
    exit 1
}
echo 'K01 v1697: native PDP-6 typed free, pins at lock/delete, PI restore and unsafe mutant PASS'
