#!/bin/sh
# An interrupt-side pin must be observed before MM removes the owner.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-relocate-pin-race-v1694.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
src="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
{
    printf '%s\n' '.text' '.globl mm_move_extent' '.equ MM_ALLOC_HIGH,1' \
        '.equ MM_TYPE_PROCESS,1'
    sed -n '/^mm_delete:$/,/^; AC1=base\. Return/p' "$src" | sed '$d'
    sed -n '/^mm_move_extent:$/,/^; int mm_compact(words, alignment)/p' \
        "$src" | sed '$d'
} > "$work/production.s"
python3 - "$self/daimos-mm-relocation-v531.s" "$work/fixture.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
anchor = '        setzm vm_calls\n'
assert s.count(anchor) == 1
s = s.replace(anchor, '''        ; Simulate a PI actor pinning the source just before PI closes.
        movei 1,1
        movem 1,inject_pin_v1694
        movei 1,0
        movei 2,02000
        pushj 17,mm_move_extent
        came 1,[-5]
        jrst fail1
        move 1,mm_extent_count
        caie 1,2
        jrst fail1
        move 1,mm_extents
        came 1,[02000,,02000]
        jrst fail1
        move 1,mm_extents+1
        came 1,[011,,07]        ; real physical pin, not stale copy
        jrst fail1
        skipn vm_calls          ; no VM mutation on pinned source
        jrst v1694_check_pi
        jrst fail1
v1694_check_pi:
        skipn pi_balance
        jrst v1694_check_type
        jrst fail1
v1694_check_type:
        move 1,[03,,07]         ; non-process descriptor
        movem 1,mm_extents+1
        movei 1,0
        movei 2,02000
        pushj 17,mm_move_extent
        came 1,[-4]
        jrst fail1
        move 1,mm_extents+1
        came 1,[03,,07]
        jrst fail1
        skipn pi_balance
        jrst v1694_check_slot
        jrst fail1
v1694_check_slot:
        move 1,[01,,07]
        movem 1,mm_extents+1
        seto 1                 ; negative source slot must not index MM
        movei 2,02000
        pushj 17,mm_move_extent
        came 1,[-4]
        jrst fail1
        move 1,mm_extent_count
        caie 1,2
        jrst fail1
        skipn pi_balance
        jrst v1694_continue
        jrst fail1
v1694_continue:
''' + anchor, 1)
anchor = '''mach_pi_disable:
        aos pi_balance
        movei 1,0123'''
assert s.count(anchor) == 1
s = s.replace(anchor, '''mach_pi_disable:
        aos pi_balance
        skipn inject_pin_v1694
        jrst v1694_pi_ready
        setzm inject_pin_v1694
        move 5,[011,,07]
        movem 5,mm_extents+1
v1694_pi_ready:
        movei 1,0123''', 1)
anchor = 'pi_balance: .block 1\n'
assert s.count(anchor) == 1
s = s.replace(anchor, anchor + 'inject_pin_v1694: .block 1\n', 1)
Path(sys.argv[2]).write_text(s)
PY
run()
{
    name=$1
    leaf=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 180000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-relocate-pin-race-v1694-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$work/fixture.s" "$leaf" > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -40 "$work/production.log" >&2
    exit 1
}
python3 - "$work/production.s" "$work/unsafe.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
old = '        tlne    3,03770\n        jrst    mm_move_pinned_locked_v1694\n'
assert s.count(old) == 1
Path(sys.argv[2]).write_text(s.replace(old, '', 1))
PY
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1694: missing pinned-owner guard unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -40 "$work/unsafe.log" >&2
    exit 1
}
echo 'K01 v1694: native PDP-6 pin-at-PI, type/slot refusal, normal relocation and mutant PASS'
