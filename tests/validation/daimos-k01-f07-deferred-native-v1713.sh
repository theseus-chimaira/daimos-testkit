#!/bin/sh
# Source-linked PDP-6 proof of safe deferred TERM after physical rollback.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-f07-deferred-native-v1713.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

python3 - "$DAIMOS_REPO/system/kernel" "$self" "$work" <<'PY'
from pathlib import Path
import runpy
import shutil
import sys

kernel_root, tests, work = map(Path, sys.argv[1:])
kernel = work / 'kernel'
for rel in ('proc/proc_swap_pdp6.s', 'storage/backstore.s',
            'storage/backstore_entry_v484.s'):
    target = kernel / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(kernel_root / rel, target)
runpy.run_path(str(tests / 'daimos-k01-f07-deferred-inject-v1713.py'))[
    'inject'](kernel)
swap = (kernel / 'proc/proc_swap_pdp6.s').read_text()
label = 'daimos_v1494_term_witness:\n'
assert swap.count(label) == 1
witness = label + swap.split(label, 1)[1]
header = '''        .text
        .globl daimos_v1494_term_witness
        .equ PROC_TRANSITION_RH,0200000
'''
(work / 'production.s').write_text(header + witness)
guard = '        tlne    5,04\n'
assert witness.count(guard) == 1
(work / 'unsafe-no-term.s').write_text(
    header + witness.replace(guard, '        tlne    5,02\n', 1))
guard = '        trnn    6,PROC_TRANSITION_RH\n'
assert witness.count(guard) == 1
(work / 'unsafe-require-lock.s').write_text(
    header + witness.replace(guard, '        trne    6,PROC_TRANSITION_RH\n', 1))
guard = '        move    4,-4(17)               ; service\'s pending slot\n'
assert witness.count(guard) == 1
(work / 'unsafe-slot.s').write_text(
    header + witness.replace(guard, '        move    4,-3(17)\n', 1))

fixture = (tests / 'daimos-k01-f07-term-stack-v1712.s').read_text()
old = '        move    1,[uarea_v1712,,0200000]\n'
assert fixture.count(old) == 1
fixture = fixture.replace(
    old, '        move    1,[uarea_v1712,,0400000]\n', 1)
old = ('        move    1,[0100000,,0]\n'
       '        movem   1,uarea_v1712+067\n')
new = ('        setzm   uarea_v1712+067\n'
       '        move    1,[04,,0]\n'
       '        movem   1,uarea_v1712+024\n')
assert fixture.count(old) == 1
fixture = fixture.replace(old, new, 1)
old = '''test_missing_prevm_v1712:
        ; Do not fabricate the PREVM marker: if it is truly absent,
        ; the original witness must count a failed integrity assertion.
        setzm   uarea_v1712+067
'''
new = '''test_missing_prevm_v1712:
        ; This owner still has a private executive continuation. A
        ; premature PREVM marker must fail the deferred TERM witness.
        move    1,[0100000,,0]
        movem   1,uarea_v1712+067
'''
assert fixture.count(old) == 1
fixture = fixture.replace(old, new, 1)
(work / 'fixture.s').write_text(fixture)

# The actual retry injection is also verified at its source anchor:
# an active TRANSITION remains required, PREVM must remain absent,
# and the same pending TERM must still be present before bitmap repair.
back = (kernel / 'storage/backstore.s').read_text()
assert back.count('daimos_v1713_retry_pending:') == 1
assert back.count('        tlnn    4,0100000\n') == 1
assert back.count('        tlne    4,04                  ; deferred TERM still owned\n') == 1
print('v1713: source-linked deferred event and retry hooks PASS')
PY

run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 160000 --timeout 25 \
        --workdir "$work/run-$name" --name "k01-f07-deferred-v1713-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$work/fixture.s" "$source" > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -50 "$work/production.log" >&2
    exit 1
}
for name in unsafe-no-term unsafe-require-lock unsafe-slot; do
    if run "$name" "$work/$name.s"; then
        echo "v1713: unsafe $name unexpectedly passed" >&2
        exit 1
    fi
    grep -q '^FAIL:' "$work/$name.log" || {
        tail -40 "$work/$name.log" >&2
        exit 1
    }
done
echo 'K01 v1713: PDP-6 safe deferred TERM, wrong-state mutants and retry anchors PASS'
