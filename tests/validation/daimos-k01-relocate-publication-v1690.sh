#!/bin/sh
# Both impossible insertion failures must HALT at distinct MM owner PCs.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-relocate-publication-v1690.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
src="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
{
    printf '%s\n' '.text' '.globl mm_move_extent' '.equ MM_ALLOC_HIGH,1'
    sed -n '/^mm_delete:$/,/^; AC1=base\. Return/p' "$src" | sed '$d'
    sed -n '/^mm_move_extent:$/,/^; int mm_compact(words, alignment)/p' "$src" | sed '$d'
} > "$work/base.s"
python3 - "$work/base.s" "$work/injected.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
old = 'mm_extent_insert:\n'
assert s.count(old) == 1
s = s.replace(old, '''mm_extent_insert:
        aos inject_calls_v1690
        move 7,inject_calls_v1690
        camn 7,inject_target_v1690
        jrst inject_refuse_v1690
        jrst inject_continue_v1690
inject_refuse_v1690:
        movni 1,3
        popj 17,
inject_continue_v1690:
''', 1)
Path(sys.argv[2]).write_text(s)
PY
for count in 1 2; do
    sed "s/INJECT_COUNT_V1690/$count/" \
        "$self/daimos-k01-relocate-publication-v1690.s" > "$work/case-$count.s"
    name="k01-relocate-publication-$count-v1690"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 150000 --timeout 25 \
        --workdir "$work/run-$count" --name "$name" \
        --expect __test_exit=1 "$self/daimos-test-crt0-v1.s" \
        "$work/case-$count.s" "$work/injected.s" > "$work/$count.log" 2>&1 || :
    python3 - "$work/run-$count/$name.report.txt" \
        "$work/run-$count/$name.labels" "$count" <<'PY'
from pathlib import Path
import re
import sys
report = Path(sys.argv[1]).read_text()
labels = Path(sys.argv[2]).read_text()
count = int(sys.argv[3])
match = re.search(r'HALT instruction, PC: ([0-7]{6})', report)
assert match, 'relocation returned instead of halting on MM owner loss'
symbols = dict(re.findall(r'(?m)^(\S+)\s+([0-7]{6})\s*$', labels))
label = ('mm_move_rollback_lost_v1690' if count == 1
         else 'mm_move_publish_lost_v1690')
assert match.group(1) == symbols[label], (match.group(1), symbols[label])
print('K01 v1690: injected insertion refusal %d halted at %s' % (count, label))
PY
done
echo 'K01 v1690: distinct native PDP-6 MM rollback/publication owner-loss HALTs PASS'
