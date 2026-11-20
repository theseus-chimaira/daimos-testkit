#!/bin/sh
# Source-linked atomic MM pin and unpin with edge-injected PI mutations.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-mm-pin-pi-v1698.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mm="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
{
    printf '%s\n' '.text' '.globl mm_pin' '.globl mm_unpin' \
        '.equ MM_PIN_ONE,010000000' '.equ MM_PIN_FIELD,03770000000'
    sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' "$mm" | sed '$d'
    sed -n '/^mm_pin_adjust:$/,/^        \.bss$/p' "$mm" | sed '$d'
} > "$work/base.s"
python3 - "$work/base.s" "$work/production.s" "$work/unsafe.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
add = 'mm_pin_add_ok:\n'
sub = 'mm_pin_sub:\n'
assert s.count(add) == 1 and s.count(sub) == 1
s = s.replace(add, '''mm_pin_add_ok:
        skipn   inject_add_v1698
        jrst    pin_add_commit_v1698
        coni    0004,0
        trne    0,000200
        jrst    pin_add_interrupt_v1698
        jrst    pin_add_commit_v1698
pin_add_interrupt_v1698:
        setzm   mm_extent_count        ; simulated interrupt MM free
        aos     injected_add_v1698
pin_add_commit_v1698:
''', 1)
s = s.replace(sub, '''mm_pin_sub:
        skipn   inject_sub_v1698
        jrst    pin_sub_commit_v1698
        coni    0004,0
        trne    0,000200
        jrst    pin_sub_interrupt_v1698
        jrst    pin_sub_commit_v1698
pin_sub_interrupt_v1698:
        move    0,[021,,01]            ; simulated second pin
        movem   0,mm_extents+1
        aos     injected_sub_v1698
pin_sub_commit_v1698:
''', 1)
Path(sys.argv[2]).write_text(s)
old = '        cono    0004,000400             ; disable global PI\n'
assert s.count(old) == 1
Path(sys.argv[3]).write_text(s.replace(
    old, '        move    0,0     ; unsafe: PI left enabled\n', 1))
PY
run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 190000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-mm-pin-pi-v1698-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-mm-pin-pi-v1698.s" "$source" \
        > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -40 "$work/production.log" >&2
    exit 1
}
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1698: unprotected MM pin read/modify/write unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -40 "$work/unsafe.log" >&2
    exit 1
}
echo 'K01 v1698: native PDP-6 atomic pin/unpin, refused unpin, missing base, interrupted updates and mutant PASS'
