#!/bin/sh
# Source-linked v1494 F07 TERM witness with a wrong-offset mutant.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-f07-term-stack-v1712.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
python3 - "$DAIMOS_REPO/system/kernel" "$self" "$work" <<'PY'
from pathlib import Path
import runpy
import shutil
import sys

root, tests, work = map(Path, sys.argv[1:])
kernel = work / 'kernel'
for rel in ('proc/proc_swap_pdp6.s', 'storage/backstore.s',
            'storage/backstore_entry_v484.s'):
    target = kernel / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / rel, target)

injector = tests / 'daimos-swap-refusal-fullguest-v1494.py'
runpy.run_path(str(injector))['inject'](kernel)
swap = (kernel / 'proc/proc_swap_pdp6.s').read_text()
label = 'daimos_v1494_term_witness:\n'
assert swap.count(label) == 1
witness = label + swap.split(label, 1)[1]
offset = '        move    4,-4(17)               ; service\'s pending slot\n'
assert witness.count(offset) == 1
header = '''        .text
        .globl daimos_v1494_term_witness
        .equ PROC_TRANSITION_RH,0200000
'''
(work / 'production.s').write_text(header + witness)
(work / 'unsafe.s').write_text(header + witness.replace(
    offset, '        move    4,-3(17)               ; unsafe return PC\n', 1))
PY
run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 160000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-f07-term-v1712-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-k01-f07-term-stack-v1712.s" "$source" \
        > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -50 "$work/production.log" >&2
    exit 1
}
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1712: wrong F07 TERM stack offset unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -50 "$work/unsafe.log" >&2
    exit 1
}
echo 'K01 v1712: genuine F07 TERM stack, owner/marker witness, wrong-offset mutant PASS'
