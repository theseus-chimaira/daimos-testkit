#!/bin/sh
# Source-linked MM verifier with a PI-gated descriptor-torn-read mutant.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-verify-pi-v1700.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mm="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
{
    printf '%s\n' '.text' '.equ MM_TYPE_PROCESS,1' \
        '.equ MM_PIN_FIELD,03770000000' '.equ MM_PIN_ONE,010000000' \
        '.globl mm_process_verify_pinned_v792'
    sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' "$mm" | sed '$d'
    sed -n '/^mm_process_verify_pinned_v792:$/,/^; Only a process extent pinned exactly once/p' \
        "$mm" | sed '$d'
} > "$work/base.s"
python3 - "$work/base.s" "$work/production.s" "$work/unsafe.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
anchor = '        move    4,mm_extents+1(1)\n'
assert s.count(anchor) == 1
mutator = '''        ; Simulate an interrupt-side length change after size read.
        skipn   inject_v1700
        jrst    verify_continue_v1700
        coni    0004,0
        trnn    0,000200
        jrst    verify_continue_v1700
        setzm   inject_v1700
        move    0,[06000,,02000]
        movem   0,mm_extents(1)
        aos     injected_v1700
verify_continue_v1700:
'''
s = s.replace(anchor, mutator + anchor, 1)
Path(sys.argv[2]).write_text(s)
lock = '        cono    0004,000400\n'
assert s.count(lock) == 1
Path(sys.argv[3]).write_text(s.replace(
    lock, '        move    0,0  ; unsafe: leave global PI enabled\n', 1))
PY
run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 170000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-verify-pi-v1700-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-verify-pi-v1700.s" "$source" \
        > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -40 "$work/production.log" >&2
    exit 1
}
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1700: torn descriptor verification unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -40 "$work/unsafe.log" >&2
    exit 1
}
echo 'K01 v1700: native PDP-6 atomic owner/length/pin snapshot, PI state, registers and torn-read mutant PASS'
