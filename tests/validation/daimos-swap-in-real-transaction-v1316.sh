#!/bin/sh
# Execute production PDP-6 swap-in with real MM, MM pins, storage modes and
# backing bitmap accounting. Disk read, reclaim and exchange admission are
# test-controlled; no booted full-system acceptance is claimed.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-in-transaction-v1316.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1316 work: $work"; fi' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel" "$work/production-v1316.s" <<'PY'
from pathlib import Path
import os
import re
import sys

root, target = (Path(s) for s in sys.argv[1:])
mm = (root / 'mm/mm_pdp6.s').read_text()
swap = (root / 'proc/proc_swap_pdp6.s').read_text()
sched = (root / 'proc/proc_pdp6.s').read_text()
storage = (root / 'proc/proc_storage_runtime_v30.s').read_text()
backstore = (root / 'storage/backstore.s').read_text()

def leaf(text, start, end):
    assert text.count(start) == 1, 'ambiguous production entry ' + start
    tail = text.split(start, 1)[1]
    assert end in tail, 'missing end for ' + start
    return start + tail.split(end, 1)[0]

equ = {}
for src in (mm, swap):
    for line in src.splitlines():
        match = re.fullmatch(r'\s*\.equ\s+(\w+),(.+)', line)
        if match:
            name, value = match.groups()
            value = value.strip()
            if name in equ and equ[name] != value:
                raise AssertionError('conflicting assembly equate: ' + name)
            equ[name] = value
for name in ('PROC_TIMER_DUE_LH', 'PROC_TIMER_CLOCK_MASK',
             'PROC_SWAP_RETRY_TICKS'):
    match = re.search(r'(?m)^\s*\.equ\s+' + name + r',([^\n]+)', sched)
    assert match, 'missing scheduler timekeeping equate ' + name
    equ[name] = match.group(1).strip()

incoming = leaf(swap, 'proc_swap_in:\n',
                '\n/* An impossible late mode mismatch')
if os.environ.get('V1316_TRACE_DIAGNOSTIC') == '1':
    diagnostics = []
    def mark(match):
        number = len(diagnostics) + 1
        label = 'proc_swap_diag_%d_v1316' % number
        diagnostics.append('%s:\n        movei   7,%o\n'
                           '        movem   7,validation_fail_v1316\n'
                           '        jrst    proc_swap_in_fail' %
                           (label, number))
        return match.group(1) + label
    incoming = re.sub(r'(?m)^((?:\s*(?:jrst|jumpn|jumpe)\s+(?:1,)?))'
                      r'proc_swap_in_fail\s*$', mark, incoming)
    incoming += '\n' + '\n'.join(diagnostics) + '\n'

parts = [
    '.text',
    '\n'.join('.equ %s,%s' % x for x in equ.items()),
    '\n'.join('.globl ' + label for label in (
        'proc_swap_in', 'proc_swap_mres_service_v481',
        'proc_swap_skip_words', 'proc_sched_pi_tick',
        'proc_select_rt_normal_swap_v879',
        'mm_alloc_aligned', 'mm_alloc_aligned_noreclaim',
        'mm_pin', 'mm_unpin', 'mm_free', 'mm_extent_insert',
        'proc_storage_expect_v30', 'proc_storage_publish_v30',
        'backstore_free')),
    leaf(mm, 'mm_delete:\n', '\n; int mm_alloc_aligned_noreclaim'),
    leaf(mm, 'mm_alloc_aligned_noreclaim:\n', '\n; Move one process extent'),
    leaf(mm, 'mm_compact:\n', '\n; int mm_alloc_aligned(words'),
    leaf(mm, 'mm_arena_fits_v1260:\n', '\n; int mm_alloc_aligned(words'),
    leaf(mm, 'mm_alloc_aligned:\n', '\n; int mm_free(base'),
    leaf(mm, 'mm_free:\n', '\n; int mm_process_transfer'),
    leaf(mm, 'mm_pin_adjust:\n', '\n        .bss\n'),
    leaf(swap, 'proc_swap_skip_words:\n', '\n.if PROC_SWAP_VERIFY_PURE'),
    incoming,
    leaf(swap, 'proc_swap_mres_service_v481:\n',
         '\nproc_swap_mres_reclaim_v481:\n'),
    leaf(storage, 'proc_storage_expect_v30:\n',
         '\n; int proc_storage_exchange_modes_v778'),
    leaf(backstore, 'backstore_verify_allocated_v795:\n',
         '\n; int backstore_extend(first,old_blocks,new_blocks)'),
    leaf(backstore, 'backstore_free:\n', '\n        .bss\n'),
    '.globl proc_sched_pi_tick\n' +
    leaf(sched, 'proc_sched_pi_tick:\n', '\nproc_sched_timer_done:\n') +
    '\nproc_sched_timer_done:\n        popj    17,',
    '.globl proc_select_rt_normal_swap_v879\n' +
    leaf(sched, 'proc_select_rt_normal_swap_v879:\n',
         '\nproc_select_runq_start:\n') +
    '\nproc_select_runq_start:\n'
    '        aos     independent_run_v1316\n'
    '        popj    17,\n'
    'proc_select_none:\n'
    '        popj    17,',
]
target.write_text('\n\n'.join(parts))
for label in ('proc_swap_in_pressure:', 'proc_swap_in_read_offset:',
              'proc_swap_in_free_fail:', 'mm_pin_add_ok:',
              'proc_storage_publish_v30:', 'backstore_free_count:',
              'proc_swap_service_cooldown_v833:'):
    assert label in target.read_text(), 'missing actual transaction: ' + label
PY

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 450000 --timeout 35 \
    --workdir "$work/run" --name swap-in-real-v1316 \
    --expect __test_exit=0 --expect proc_timer_clock=0100 \
    --expect proc_swap_pressure_ticks=0 \
    --expect read_calls_v1316=1 --expect free_calls_v1316=0 \
    --expect independent_run_v1316=1 \
    --expect event_calls_v1313=0 --expect mm_extent_count=1 \
    --expect backstore_blocks_used=0 --expect proc_swap_blocks_used=0 \
    --examine validation_fail_v1316 \
    --examine event_calls_v1313 --examine pair_calls_v1313 \
    --examine fs_reclaim_calls_v1313 --examine swap_reclaim_calls_v1313 \
    "$self/daimos-test-crt0-v1.s" "$work/production-v1316.s" \
    "$self/daimos-swap-in-real-transaction-v1316.s" \
    > "$work/log" 2>&1 || {
        tail -75 "$work/log" >&2
        exit 1
    }
echo 'v1316: source-authentic swap-in MM allocation/pin/restore '
echo 'v1316: commit/backing bitmap and PI6 no-partner retry PASS '
echo 'v1316: (backstore_read mocked; not full booted guest)'

# Fail the *test disk provider*, not the production MM or the transaction.
# The production rollback must unpin/free the newly allocated extent,
# retain the original bitmap allocation and disk record, clear the
# TRANSITION lock and deliver exactly one fatal TERM event.
python3 - "$self/daimos-swap-in-real-transaction-v1316.s" \
    "$work/read-failure-v1317.s" \
    "$work/production-v1316.s" "$work" <<'PY'
from pathlib import Path
import sys

fixture, negative, original, work = (Path(x) for x in sys.argv[1:])
source = fixture.read_text()
old = 'read_fault_v1316: .word 0'
assert source.count(old) == 1
negative.write_text(source.replace(old, 'read_fault_v1316: .word 1'))
production = original.read_text()
mutants = (
    ('leak-on-read-failure',
     'proc_swap_in_free_fail:\n        move    1,(17)\n'
     '        movei   2,MM_TYPE_PROCESS\n        move    3,10\n'
     '        pushj   17,mm_free',
     'proc_swap_in_free_fail:\n        move    1,(17)\n'
     '        movei   2,MM_TYPE_PROCESS\n        move    3,10\n'
     '        setz    1,'),
    ('no-backing-free',
     'backstore_free:\n        push    17,1',
     'backstore_free:\n        jrst    backstore_free_return\n'
     '        push    17,1'),
    ('no-storage-publication',
     'proc_storage_publish_v30:\n        caile   3,2',
     'proc_storage_publish_v30:\n        setz    1,\n'
     '        popj    17,\n        caile   3,2'),
)
for name, old, new in mutants:
    assert production.count(old) == 1, 'production mutation anchor: ' + name
    (work / ('unsafe-' + name + '-v1317.s')).write_text(
        production.replace(old, new, 1))
PY

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 450000 --timeout 35 \
    --workdir "$work/read-failure" --name swap-read-failure-v1317 \
    --expect __test_exit=0 --expect proc_timer_clock=0100 \
    --expect independent_run_v1316=1 --expect read_calls_v1316=1 \
    --expect event_calls_v1313=1 --expect mm_extent_count=0 \
    --expect backstore_blocks_used=010 --expect proc_swap_blocks_used=010 \
    "$self/daimos-test-crt0-v1.s" "$work/production-v1316.s" \
    "$work/read-failure-v1317.s" > "$work/read-failure.log" 2>&1 || {
        tail -70 "$work/read-failure.log" >&2
        exit 1
    }
echo 'v1317: actual swap-in MM unpin/free rollback and disk backing retention PASS'

for mutant in leak-on-read-failure no-backing-free no-storage-publication; do
    if [ "$mutant" = leak-on-read-failure ]; then
        fixture="$work/read-failure-v1317.s"
    else
        fixture="$self/daimos-swap-in-real-transaction-v1316.s"
    fi
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 450000 --timeout 35 \
        --workdir "$work/unsafe-$mutant" --name "unsafe-$mutant-v1317" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$work/unsafe-$mutant-v1317.s" "$fixture" \
        > "$work/unsafe-$mutant.log" 2>&1; then
        echo "v1317: unsafe mutation accepted: $mutant" >&2
        exit 1
    fi
    grep -q '^FAIL:' "$work/unsafe-$mutant.log" || {
        echo "v1317: unsafe mutant did not reach executable assertion: $mutant" >&2
        tail -40 "$work/unsafe-$mutant.log" >&2
        exit 1
    }
    echo "v1317: rejected executable mutation: $mutant"
done
echo 'v1317: three actual assembly transaction mutants rejected PASS'
