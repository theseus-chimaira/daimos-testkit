#!/bin/sh
# Native MM rollback: no destination must restore descriptor and PI state.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-relocate-rollback-v1688.XXXXXX")
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
src = Path(sys.argv[1]).read_text()
anchor = '        setzm vm_calls\n'
assert src.count(anchor) == 1
src = src.replace(anchor, '''        ; No fitting destination: the original descriptor must survive.
        movei 1,1
        movem 1,result_step
        movei 1,0
        movei 2,02000
        pushj 17,mm_move_extent
        came 1,[-2]
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
        move 1,pi_balance
        jumpn 1,fail1
        setzm result_step
''' + anchor)
anchor = 'mm_find_fit:\n'
assert src.count(anchor) == 1
src = src.replace(anchor, '''mm_find_fit:
        skipn result_step
        jrst fit_available_v1688
        movei 5,05000
        movem 5,(4)
        setz 1,
        popj 17,
fit_available_v1688:
''')
Path(sys.argv[2]).write_text(src)
PY
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 200000 --timeout 25 \
    --workdir "$work/run" --name daimos-k01-relocate-rollback-v1688 \
    --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
    "$work/fixture.s" "$work/production.s" > "$work/run.log" 2>&1 || {
        tail -35 "$work/run.log" >&2
        exit 1
    }
# Mutate only the rollback insertion, not the successful publication.
python3 - "$work/production.s" "$work/unsafe.s" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text()
old = '''        move    1,010
        movei   2,-5(17)
        pushj   17,mm_extent_insert
        skipn   (17)'''
new = '''        move    1,010
        movei   2,-5(17)
        setz    1,
        skipn   (17)'''
assert src.count(old) == 1
Path(sys.argv[2]).write_text(src.replace(old, new, 1))
PY
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 200000 --timeout 25 \
    --workdir "$work/unsafe" --name daimos-k01-relocate-rollback-unsafe-v1688 \
    --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
    "$work/fixture.s" "$work/unsafe.s" > "$work/unsafe.log" 2>&1; then
    echo 'K01 v1688: missing rollback insertion unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -35 "$work/unsafe.log" >&2
    exit 1
}
echo 'K01 v1688: native PDP-6 no-fit rollback, PI balance, VM refusal, valid move and unsafe mutant PASS'
