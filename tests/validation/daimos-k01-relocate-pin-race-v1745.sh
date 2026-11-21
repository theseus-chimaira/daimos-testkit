#!/bin/sh
# An interrupt-side pin must be observed before MM removes the owner.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-relocate-pin-race-v1745.XXXXXX")
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
s = s.replace('main:\n', 'main:\n        cono 0004,02026   ; enable PI3/PI5/PI6\n        cono 0004,000200  ; enable global PI\n', 1)
s = s.replace(anchor, '''        ; Confirm that PI6 is inhibited and disk PI3/PI5 stay live.
        movei 1,1
        movem 1,inject_pin_v1745
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
        skipn pi_state_bad_v1745
        jrst v1745_pi_ok
        jrst fail1
v1745_pi_ok:
        coni 0004,7
        trnn 7,000002
        jrst fail1
        skipn vm_calls          ; no VM mutation on pinned source
        jrst v1745_check_pi
        jrst fail1
v1745_check_pi:
        skipn pi_balance
        jrst v1745_check_type
        jrst fail1
v1745_check_type:
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
        jrst v1745_check_slot
        jrst fail1
v1745_check_slot:
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
        jrst v1745_continue
        jrst fail1
v1745_continue:
''' + anchor, 1)
anchor = 'pi_balance: .block 1\n'
assert s.count(anchor) == 1
s = s.replace(anchor, anchor + '.globl inject_pin_v1745\n' +
              'inject_pin_v1745: .block 1\n' +
              '.globl pi_state_bad_v1745\npi_state_bad_v1745: .block 1\n', 1)
Path(sys.argv[2]).write_text(s)
PY
# Insert a test-only PI actor at the real source boundary and inspect
# PI6 closure without suppressing disk PI3/PI5.
python3 - "$work/production.s" <<'PYPATCH'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
anchor = '        coni    0004,1\n        movem   1,-3(17)\n        cono    0004,01002\n'
assert s.count(anchor) == 1
s = s.replace(anchor, '''        ; Inject a real descriptor mutation immediately before PI6 closure.
        skipn inject_pin_v1745
        jrst v1745_pi_ready
        setzm inject_pin_v1745
        move 5,[011,,07]
        movem 5,mm_extents+1
v1745_pi_ready:
        coni    0004,1
        movem   1,-3(17)
        cono    0004,01002
        coni    0004,7
        trnn    7,000200
        aos     pi_state_bad_v1745
        trnn    7,000004
        aos     pi_state_bad_v1745
        trnn    7,000020
        aos     pi_state_bad_v1745
        trne    7,000002
        aos     pi_state_bad_v1745
''', 1)
p.write_text(s)
PYPATCH
run()
{
    name=$1
    leaf=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 180000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-relocate-pin-race-v1745-$name" \
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
    echo 'K01 v1745: missing pinned-owner guard unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -40 "$work/unsafe.log" >&2
    exit 1
}
python3 - "$work/production.s" "$work" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
work = Path(sys.argv[2])
anchor = '        cono    0004,01002\n'
assert s.count(anchor) == 1
for name, replacement in (
        ('unsafe-global', '        cono    0004,000400\n'),
        ('unsafe-pi6', '        move    0,0\n')):
    (work / (name + '.s')).write_text(s.replace(anchor, replacement, 1))
anchor = '        trne    1,000002\n        cono    0004,02002\n'
assert s.count(anchor) == 2
(work / 'unsafe-restore.s').write_text(s.replace(
    anchor, '        move    0,0\n        move    0,0\n'))
PY
for name in unsafe-global unsafe-pi6 unsafe-restore; do
    if run "$name" "$work/$name.s"; then
        echo "K01 v1745: $name mutation unexpectedly passed" >&2
        exit 1
    fi
    grep -q '^FAIL:' "$work/$name.log" || {
        tail -40 "$work/$name.log" >&2
        exit 1
    }
done
echo 'K01 v1745: native PI6-only MM move, disk PI3/PI5 and four mutants PASS'
