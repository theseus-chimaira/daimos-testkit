#!/bin/sh
# Source-link the real slot-0 swap service, real swap-in, and real bitmap free.
# Backend device and MM responses are controlled by the prior v1405 fixture.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-checked-scheduler-v1493.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1493 work: $work"; fi' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel" "$self" "$work" <<'PY'
from pathlib import Path
import re
import sys

kernel, tests, work = map(Path, sys.argv[1:])
swap = (kernel / 'proc/proc_swap_pdp6.s').read_text()
backing = (kernel / 'storage/backstore.s').read_text()
fixture = (tests / 'daimos-swap-in-checked-release-v1405.s').read_text()

def leaf(source, first, last):
    if source.count(first) != 1:
        raise AssertionError('ambiguous production entry: ' + first)
    tail = source.split(first, 1)[1]
    if last not in tail:
        raise AssertionError('missing production boundary: ' + last)
    return first + tail.split(last, 1)[0]

equ = [line for line in swap.splitlines()
       if re.match(r'^\s*\.equ\s+\w+\s*,', line)]
service = leaf(swap, 'proc_swap_mres_service_v481:\n',
               '\nproc_swap_mres_reclaim_v481:\n')
incoming = leaf(swap, 'proc_swap_in:\n',
                '\n/* An impossible late mode mismatch')
parts = [
    '.text', '\n'.join(equ),
    '.globl proc_swap_mres_service_v481\n.globl proc_swap_in',
    leaf(swap, 'proc_swap_skip_words:\n', '\n.if PROC_SWAP_VERIFY_PURE'),
    incoming, service,
    leaf(backing, 'backstore_verify_allocated_v795:\n',
         '\n; int backstore_extend(first,old_blocks,new_blocks)'),
    leaf(backing, 'backstore_free:\n', '\n        .bss\n'),
]
(work / 'production-v1493.s').write_text('\n\n'.join(parts) + '\n')
stub_start = '        .globl mm_alloc_aligned\n'
if fixture.count(stub_start) != 1:
    raise AssertionError('changed v1405 MM/backend test fixture')
(work / 'fixture-v1493.s').write_text(fixture.split(stub_start, 1)[1])
# The extracted fixture begins at the MM stub's global directive.
p = work / 'fixture-v1493.s'
p.write_text('.globl mm_alloc_aligned\n' + p.read_text())
# The v1405 fixture owns local descriptor/u-area/stack labels. Keep the
# dedicated scheduler test and those local labels in one assembler unit.
(work / 'driver-v1493.s').write_text(
    (tests / 'daimos-swap-checked-scheduler-v1493.s').read_text() +
    '\n' + p.read_text())
PY

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 180000 --timeout 25 \
    --workdir "$work/run" --name swap-checked-scheduler-v1493 \
    --expect __test_exit=0 --expect event_calls_v1493=1 \
    --expect event_slot_v1493=2 --expect event_kind_v1493=1 \
    --expect proc_sched_cursor=2 --expect proc_swap_pressure_ticks=0 \
    --expect unexpected_exchange_v1493=0 \
    --expect __rollback_calls_v1405=1 --expect __publish_calls_v1405=0 \
    --expect __invariant_calls_v1405=0 \
    --expect __read_calls_v1405=1 --expect __read_bad_v1405=0 \
    "$self/daimos-test-crt0-v1.s" "$work/production-v1493.s" \
    "$work/driver-v1493.s" > "$work/test.log" 2>&1 || {
        tail -75 "$work/test.log" >&2
        exit 1
    }
echo 'PASS v1493: real slot-0 swap service routes refused release to TERM'
echo 'PASS v1493: DISK owner/bitmap intact, no RESIDENT or READY_ONCE'

# Negative control: falsely classify the failed free as successful.
# The assertion must reject the premature publication and missing TERM.
python3 - "$work/production-v1493.s" "$work/unchecked-v1493.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
old = ('        pushj   17,backstore_free\n'
       '        jumpn   1,proc_swap_in_free_fail\n')
if source.count(old) != 1:
    raise AssertionError('checked release gate changed')
Path(sys.argv[2]).write_text(source.replace(old,
    '        pushj   17,backstore_free\n        setz    1,\n', 1))
PY
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 180000 --timeout 25 \
    --workdir "$work/unchecked" --name unchecked-scheduler-v1493 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/unchecked-v1493.s" \
    "$work/driver-v1493.s" > "$work/unchecked.log" 2>&1; then
    echo 'FAIL v1493: unchecked release mutation passed' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit:' "$work/unchecked.log" || {
    echo 'FAIL v1493: mutated test did not reach the assertion' >&2
    tail -35 "$work/unchecked.log" >&2
    exit 1
}
echo 'PASS v1493: false-success mutation rejected'

# Negative control: the scheduler must not treat a failed transaction
# as completed (the transaction itself remains fully checked).
python3 - "$work/production-v1493.s" "$work/false-ready-v1493.s" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
old = ('        jumpg   1,proc_swap_service_pressure\n'
       '        jumpn   1,proc_swap_service_failed\n')
if source.count(old) != 1:
    raise AssertionError('scheduler negative-result gate changed')
Path(sys.argv[2]).write_text(source.replace(old,
    '        jumpg   1,proc_swap_service_pressure\n'
    '        jrst    proc_swap_service_restore_done_v842\n', 1))
PY
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 180000 --timeout 25 \
    --workdir "$work/false-ready" --name false-ready-v1493 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/false-ready-v1493.s" \
    "$work/driver-v1493.s" > "$work/false-ready.log" 2>&1; then
    echo 'FAIL v1493: failed transaction marked ready' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit:' "$work/false-ready.log" || {
    echo 'FAIL v1493: false-ready test did not reach assertion' >&2
    tail -35 "$work/false-ready.log" >&2
    exit 1
}
echo 'PASS v1493: false-READY_ONCE mutation rejected'
