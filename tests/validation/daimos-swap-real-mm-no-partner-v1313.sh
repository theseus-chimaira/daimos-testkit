#!/bin/sh
# Native PDP-6: actual allocator occupancy -> no-partner -> real MM free.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-real-mm-no-partner-v1313.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1313 work: $work"; fi' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" \
    "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" \
    "$work/production-v1313.s" "$work" <<'PY'
from pathlib import Path
import sys

mm, swap, target, work = (Path(x) for x in sys.argv[1:])
mm = mm.read_text()
swap = swap.read_text()

def leaf(text, start, end):
    assert text.count(start) == 1, 'missing unique source anchor ' + start
    remainder = text.split(start, 1)[1]
    assert end in remainder, 'missing leaf end anchor ' + end
    return start + remainder.split(end, 1)[0]

parts = [
    '.text\n.globl proc_swap_mres_service_v481\n'
    '.globl mm_alloc_aligned\n.globl mm_alloc_aligned_noreclaim\n'
    '.globl mm_free\n.globl mm_extent_insert\n',
    '\n'.join(line for line in mm.splitlines() if line.startswith('        .equ    ')) + '\n',
    leaf(mm, 'mm_delete:\n', '\n; int mm_alloc_aligned_noreclaim'),
    leaf(mm, 'mm_alloc_aligned_noreclaim:\n', '\n; Move one process extent'),
    leaf(mm, 'mm_compact:\n', '\n; int mm_alloc_aligned(words'),
    leaf(mm, 'mm_arena_fits_v1260:\n', '\n; int mm_alloc_aligned(words'),
    leaf(mm, 'mm_alloc_aligned:\n', '\n; int mm_free(base'),
    leaf(mm, 'mm_free:\n', '\n; int mm_process_transfer'),
    '.equ PROC_SCHED_SWAP_REQUEST,0400\n'
    '.equ PROC_SLOT_MASK,0377\n'
    '.equ PROC_STATE_RUN,2\n'
    '.equ PROC_TRANSITION_RH,0200000\n'
    '.equ PROC_SCHED_READY_ONCE,01000\n'
    '.equ SYS_EVENT_TERM,1\n',
    leaf(swap, 'proc_swap_mres_service_v481:\n',
         '\nproc_swap_mres_reclaim_v481:\n'),
]
joined = '\n'.join(parts)
for label in ('mm_alloc_nr_nomem:', 'mm_alloc_aligned_pressure:',
              'mm_compact_scan:', 'proc_swap_service_no_pair_v834:',
              'proc_swap_service_restore_done_v842:'):
    assert label in joined, 'missing actual source path ' + label
target.write_text(joined)

# These mutations must be rejected by the executable PDP-6 test,
# not merely by a text pattern or a simulated failure status.
mutants = (
    ('pressure-collapse', 'mm_alloc_nr_nomem:\n        seto    1,',
     'mm_alloc_nr_nomem:\n        setz    1,'),
    ('no-filesystem-reclaim',
     'mm_alloc_aligned_pressure:\n        caige   016,2',
     'mm_alloc_aligned_pressure:\n        caige   016,0'),
    ('no-swap-reclaim', '        caige   016,3\n'
     '        jrst    mm_alloc_aligned_pressure',
     '        caige   016,2\n'
     '        jrst    mm_alloc_aligned_pressure'),
    ('lost-cooldown', '        movei   1,0100\n'
     '        movem   1,proc_swap_pressure_ticks',
     '        setz    1,\n'
     '        movem   1,proc_swap_pressure_ticks'),
)
for name, old, new in mutants:
    assert joined.count(old) == 1, 'v1313 mutation anchor: ' + name
    (work / ('unsafe-' + name + '-v1313.s')).write_text(
        joined.replace(old, new, 1))
PY

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 350000 --timeout 30 \
    --workdir "$work/run" --name swap-real-mm-v1313 \
    --expect __test_exit=0 \
    --expect alloc_fail_v1313=1 --expect alloc_success_v1313=1 \
    --expect pair_calls_v1313=3 --expect exchange_calls_v1313=0 \
    --expect fs_reclaim_calls_v1313=2 \
    --expect swap_reclaim_calls_v1313=1 \
    --expect event_calls_v1313=0 \
    "$self/daimos-test-crt0-v1.s" "$work/production-v1313.s" \
    "$self/daimos-swap-real-mm-no-partner-v1313.s" \
    > "$work/log" 2>&1 || {
        tail -65 "$work/log" >&2
        exit 1
    }
echo 'v1313: real production MM extent shortage, no eligible partner, '
echo 'v1313: backing preserved, real MM owner free and resumed native '
echo 'v1313: slot-0 service PASS (not a full booted guest)'

for mutant in pressure-collapse no-filesystem-reclaim no-swap-reclaim \
    lost-cooldown; do
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 350000 --timeout 30 \
        --workdir "$work/unsafe-$mutant" --name "unsafe-$mutant-v1313" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$work/unsafe-$mutant-v1313.s" \
        "$self/daimos-swap-real-mm-no-partner-v1313.s" \
        > "$work/unsafe-$mutant.log" 2>&1; then
        echo "v1313: unsafe mutation accepted: $mutant" >&2
        exit 1
    fi
    grep -q '^FAIL:' "$work/unsafe-$mutant.log" || {
        echo "v1313: unsafe mutant did not reach executable assertion: $mutant" >&2
        tail -40 "$work/unsafe-$mutant.log" >&2
        exit 1
    }
    echo "v1313: rejected executable mutation: $mutant"
done
echo 'v1313: four executable allocator/scheduler mutants rejected PASS'
