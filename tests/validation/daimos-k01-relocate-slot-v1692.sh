#!/bin/sh
# Native PDP-6 source-linked invalid owner rejection with a forged next slot.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-relocate-slot-v1692.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
{
    printf '%s\n' '.text' '.globl vm_extent_move' '.globl fs_move_words'
    sed -n '/^vm_extent_move:$/,/^\/\*\*$/p' \
        "$DAIMOS_REPO/system/kernel/proc/vm_pdp6.s" | sed '$d'
    sed -n '/^fs_copy_words:$/,/^        \.globl  fs_zero_words/p' \
        "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" | sed '$d'
    printf '%s\n' '.data' '.globl kconst_6_6' 'kconst_6_6: .word 6,,6'
} > "$work/production.s"
python3 - "$work/production.s" "$work/unsafe.s" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text()
guard = '        caml    10,proc_slots\n        jrst    vm_extent_move_busy\n'
assert src.count(guard) == 1
Path(sys.argv[2]).write_text(src.replace(guard, '', 1))
PY
run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 200000 --timeout 25 \
        --workdir "$work/$name" --name "k01-relocate-slot-v1692-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-relocate-slot-v1692.s" "$source" \
        > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -35 "$work/production.log" >&2
    exit 1
}
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1692: unchecked out-of-range owner unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -35 "$work/unsafe.log" >&2
    exit 1
}
echo 'K01 v1692: native PDP-6 owner slot bounds, forged next record, valid move and mutant PASS'
