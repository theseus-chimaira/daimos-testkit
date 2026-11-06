#!/bin/sh
# Native PDP-6 extracted BRK plus real arena-size feasibility leaf.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work=$(mktemp -d "$TMPDIR/daimos-mm-brk-v1260.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
vm="$DAIMOS_REPO/system/kernel/proc/vm_pdp6.s"
mm="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
{
    printf '.text\n.globl vm_space_brk_current\n.globl mm_arena_fits_v1260\n'
    sed -n '/^vm_space_brk_current:$/,/^vm_space_create:$/p' "$vm" | sed '$d'
    sed -n '/^mm_arena_fits_v1260:$/,/^; int mm_alloc_aligned(words/p' "$mm" | sed '$d'
} > "$work/brk.s"
python3 - "$work/brk.s" "$work/brk-no-check.s" "$work/brk-wrong-cause.s" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
guard = '        jumpe   1,vm_brk_impossible_v1260\n'
if source.count(guard) != 1:
    raise SystemExit('v1260: missing early physical BRK guard')
Path(sys.argv[2]).write_text(source.replace(
    guard, '        jumpe   1,vm_brk_full_alloc\n', 1))
typed = 'vm_brk_impossible_v1260:\n'
cause = '        seto    2,\n'
if source.count(typed) != 1 or source.split(typed, 1)[1].count(cause) < 1:
    raise SystemExit('v1260: missing typed physical NOMEM branch')
head, tail = source.split(typed, 1)
if cause not in tail:
    raise SystemExit('v1260: impossible branch has no typed result')
Path(sys.argv[3]).write_text(head + typed +
    tail.replace(cause, '        movni   2,4\n', 1))
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
        "$self/daimos-mm-brk-impossible-v1260.s" \
        > "$work/$name.log" 2>&1 || {
            tail -48 "$work/$name.log" >&2
            return 1
        }
}
run_case mm-brk-valid-v1260 0 "$work/brk.s"
run_case mm-brk-no-guard-v1260 6 "$work/brk-no-check.s"
run_case mm-brk-wrong-cause-v1260 2 "$work/brk-wrong-cause.s"
echo 'v1260: native full BRK typed -1, unchanged VM/BRK and no reclaim; two mutants PASS'
