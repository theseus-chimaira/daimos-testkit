#!/bin/sh
# PDP-6 production arena feasibility and effect-free impossible allocation.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work=$(mktemp -d "$TMPDIR/daimos-mm-arena-v1260.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
src="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
{
    awk '/^[[:space:]]*\.equ[[:space:]]/ {print}' "$src"
    printf '\n        .text\n        .globl mm_arena_fits_v1260\n'
    sed -n '/^mm_arena_fits_v1260:$/,/^; int mm_alloc_aligned(words/p' "$src" | sed '$d'
    printf '\n        .globl mm_alloc_aligned\n'
    sed -n '/^mm_alloc_aligned:$/,/^; int mm_free(base/p' "$src" | sed '$d'
} > "$work/allocator.s"

python3 - "$work/allocator.s" "$work/no-bound.s" "$work/no-align.s" \
    "$DAIMOS_REPO/system/kernel/proc/vm_pdp6.s" <<'PY'
from pathlib import Path
import sys
body = Path(sys.argv[1]).read_text()
start = body.index('mm_arena_fits_v1260:\n')
end = body.index('mm_arena_fits_next_v1260:', start)
always = body[:start] + 'mm_arena_fits_v1260:\n' + \
    '        movei   1,1\n        popj    17,\n' + body[end:]
Path(sys.argv[2]).write_text(always)
needle = '        andcm   6,7                   ; aligned start, no MM mutation\n'
if body.count(needle) != 1:
    raise SystemExit('v1260: production alignment calculation missing')
Path(sys.argv[3]).write_text(body.replace(needle, '', 1))
vm = Path(sys.argv[4]).read_text()
hook = '''        move    1,15
        movei   2,02000
        pushj   17,mm_arena_fits_v1260
        jumpe   1,vm_brk_impossible_v1260
'''
if vm.count(hook) != 1 or 'vm_brk_impossible_v1260:\n' not in vm:
    raise SystemExit('v1260: missing early BRK capacity check')
typed = 'vm_brk_impossible_v1260:\n'
if vm.count(typed) != 1 or '        seto    2,\n' not in vm.split(typed, 1)[1][:230]:
    raise SystemExit('v1260: invalid physical NOMEM cause')
PY

run_case()
{
    name=$1
    expected=$2
    source=$3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 300000 --timeout 20 \
        --workdir "$work/$name" --name "$name" \
        --expect "__test_exit=$expected" \
        "$self/daimos-test-crt0-v1.s" "$source" \
        "$self/daimos-mm-arena-feasibility-v1260.s" \
        > "$work/$name.log" 2>&1 || {
            tail -50 "$work/$name.log" >&2
            return 1
        }
}
run_case mm-arena-v1260 0 "$work/allocator.s"
run_case mm-arena-unbounded-v1260 1 "$work/no-bound.s"
run_case mm-arena-no-align-v1260 2 "$work/no-align.s"
echo 'v1260: native arena capacity, exact alignment, typed MM result, no victim I/O, two mutants PASS'
