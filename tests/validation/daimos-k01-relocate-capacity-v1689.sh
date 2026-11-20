#!/bin/sh
# Prove the MM descriptor rollback precondition before destructive delete.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-relocate-capacity-v1689.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
src="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
{
    printf '%s\n' '.text' '.globl mm_move_extent' '.equ MM_ALLOC_HIGH,1'
    sed -n '/^mm_delete:$/,/^; AC1=base\. Return/p' "$src" | sed '$d'
    sed -n '/^mm_move_extent:$/,/^; int mm_compact(words, alignment)/p' "$src" | sed '$d'
} > "$work/production.s"
python3 - "$self/daimos-mm-relocation-v531.s" "$work/fixture.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
anchor = '        setzm vm_calls\n'
assert s.count(anchor) == 1
s = s.replace(anchor, '''        ; Corrupt table capacity: reject before mm_delete or PI disable.
        movei 1,1
        movem 1,mm_extent_capacity
        movei 1,0
        movei 2,02000
        pushj 17,mm_move_extent
        came 1,[-4]
        jrst fail1
        move 1,mm_extent_count
        caie 1,2
        jrst fail1
        move 1,mm_extents
        came 1,[02000,,02000]
        jrst fail1
        move 1,mm_extents+1
        came 1,[01,,07]
        jrst fail1
        move 1,mm_extents+2
        came 1,[02000,,010000]
        jrst fail1
        skipn pi_balance
        jrst capacity_pi_ok_v1689
        jrst fail1
capacity_pi_ok_v1689:
        movei 1,4
        movem 1,mm_extent_capacity
        ; Out-of-range slot must not delete the last descriptor.
        movei 1,2
        movei 2,02000
        pushj 17,mm_move_extent
        came 1,[-4]
        jrst fail1
        move 1,mm_extent_count
        caie 1,2
        jrst fail1
''' + anchor)
Path(sys.argv[2]).write_text(s)
PY
run()
{
    name=$1
    leaf=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 180000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-relocate-capacity-v1689-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$work/fixture.s" "$leaf" > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -30 "$work/production.log" >&2
    exit 1
}
python3 - "$work/production.s" "$work/unsafe.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
old = '        camle   1,mm_extent_capacity\n'
assert s.count(old) == 1
Path(sys.argv[2]).write_text(s.replace(old, '        move    1,mm_extent_capacity\n', 1))
PY
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1689: bypassed descriptor-capacity guard passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -30 "$work/unsafe.log" >&2
    exit 1
}
echo 'K01 v1689: native PDP-6 corrupt table/slot fail closed, normal relocation, unsafe mutant PASS'
