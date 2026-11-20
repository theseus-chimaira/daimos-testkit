#!/bin/sh
# v1705: source-authentic swap-in BACKSTORE failure/TERM instrumentation.
# Validate current anchors before the expensive disposable full guest.
set -eu
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-swap-restore-injection-v1705.XXXXXX")
if [ "${K01_KEEP_WORK:-0}" = 1 ]; then
    echo "K01 v1705 source work: $work"
else
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

python3 - "$DAIMOS_REPO/system/kernel" "$self" "$work" <<'PY'
from pathlib import Path
import runpy
import shutil
import sys

kernel = Path(sys.argv[1])
tests = Path(sys.argv[2])
work = Path(sys.argv[3])
leaves = ('proc/proc_swap_pdp6.s', 'storage/backstore.s',
          'storage/backstore_entry_v484.s')


def source_copy(where):
    for rel in leaves:
        target = where / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(kernel / rel, target)


old = (tests / 'daimos-swap-refusal-fullguest-v1494.py')
diagnostic = (tests / 'daimos-swap-refusal-instrument-v1495.py')
old_inject = runpy.run_path(str(old))['inject']
diagnostic_inject = runpy.run_path(str(diagnostic))['inject']

# Preserve the real per-owner retry epoch and the original TERM route.
original = (kernel / leaves[0]).read_text()
retry = '''        hrrz    3,proc_timer_clock
        hrli    3,PROC_SWAP_RETRY_LH
        movem   3,PROC_FINALIZE_OFFSET(4)
proc_swap_service_failed_event_v1507:
        movei   2,SYS_EVENT_TERM
        pushj   17,proc_event_apply
'''
assert original.count(retry) == 1, 'v1705: real retry/TERM anchor drift'

target = work / 'v1494' / 'kernel'
source_copy(target)
old_inject(target)
swap = (target / leaves[0]).read_text()
assert swap.count(retry) == 1
assert swap.count('        pushj   17,daimos_v1494_term_witness\n') == 1
assert swap.count('        pushj   17,daimos_v1494_arm\n') == 1
assert swap.index('        pushj   17,proc_event_apply\n'
                  '        pushj   17,daimos_v1494_term_witness') > swap.index(
                      'proc_swap_service_failed_event_v1507:')
# The separate v1494 TERM stack-witness correction may be present in
# an uncommitted local worktree. Neither spelling is a prerequisite for
# the v1705 event-boundary fix; the v1495 diagnostic handles both.
old_stack = '        move    4,-3(17)               ; service\'s pending slot'
new_stack = '        move    4,-4(17)               ; service\'s pending slot'
assert (old_stack in swap) != (new_stack in swap)
store = (target / leaves[1]).read_text()
assert store.count('daimos_v1494_free_original:') == 1
assert store.count('daimos_v1494_retry_marked:') == 1
print('v1705: real source-linked v1494 restore/TERM/PREVM hooks PASS')

target = work / 'v1495' / 'kernel'
source_copy(target)
diagnostic_inject(target)
swap = (target / leaves[0]).read_text()
assert swap.count('daimos_v1495_event_returned') >= 1
assert swap.count('daimos_v1495_term_mark_error') >= 1
assert swap.count('daimos_v1494_term_witness:') == 1
store = (target / leaves[1]).read_text()
assert 'daimos_v1495_retry_marker' in store
assert 'daimos_v1495_retry_mark_error' in store
print('v1705: real source-linked v1495 diagnostic extension PASS')

# Negative control: deleting the new v1507 event boundary must cause
# the injector to refuse instead of instrumenting another call site.
target = work / 'unsafe-stale-event' / 'kernel'
source_copy(target)
source = (target / leaves[0]).read_text()
event = 'proc_swap_service_failed_event_v1507:\n'
assert source.count(event) == 1
(target / leaves[0]).write_text(source.replace(
    event, 'proc_swap_service_failed_event_v1705_invalid:\n', 1))
try:
    old_inject(target)
except AssertionError as err:
    assert 'v1494 production anchor drift' in str(err)
else:
    raise AssertionError('v1705: stale TERM hook was accepted')
print('v1705: unsafe stale-event mutation rejected PASS')
PY
