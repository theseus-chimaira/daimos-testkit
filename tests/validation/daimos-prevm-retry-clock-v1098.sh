#!/bin/sh
# Actual PDP-6 finalizer retry-clock leaf with three unsafe source mutants.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-prevm-clock-v1098.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1098 work: $work"; fi' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

src = (Path(sys.argv[1]) / 'system/kernel/proc/proc_pdp6.s').read_text()
work = Path(sys.argv[2])
start = 'proc_finish_mark_pending_v892:'
end = 'proc_finish_fail:'
assert src.count(start) == 1 and src.count(end) == 1
leaf = src.split(start, 1)[1].split(end, 1)[0]
header = ('.text\n.equ PROC_FINALIZE_OFFSET,067\n'
          '.equ PROC_FINALIZE_MARK_LH,0400000\n'
          '.equ PROC_TIMER_CLOCK_MASK,0377777\n'
          '.globl proc_finish_mark_pending_v892\n'
          'proc_finish_mark_pending_v892:')
source = header + leaf
assert 'proc_finish_new_pending_v1098:' in source
assert 'move    5,proc_timer_clock' in source
assert 'tlne    5,0400000' in source
(work / 'leaf.s').write_text(source)
mutants = {
    'skip-clock': ('        tlnn    5,PROC_FINALIZE_MARK_LH',
                   '        tlne    5,PROC_FINALIZE_MARK_LH'),
    'stale-epoch': ('        move    5,proc_timer_clock',
                    '        hrrz    5,proc_finish_last_tick_v881'),
    'reset-backoff': ('        tlne    5,0400000',
                      '        tlnn    5,0400000'),
}
for label, (before, after) in mutants.items():
    assert source.count(before) == 1, label
    (work / ('unsafe-' + label + '.s')).write_text(
        source.replace(before, after, 1))
PY
run_case() {
    name=$1
    file=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 30000 --timeout 15 \
        --workdir "$work/run-$name" --name "prevm-clock-v1098-$name" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-prevm-retry-clock-v1098.s" "$file" \
        >"$work/log-$name" 2>&1
}
if ! run_case normal "$work/leaf.s"; then
    tail -65 "$work/log-normal" >&2
    exit 1
fi
for name in skip-clock stale-epoch reset-backoff; do
    if run_case "$name" "$work/unsafe-$name.s"; then
        echo "v1098: $name unsafe mutation unexpectedly passed" >&2
        exit 1
    fi
done
echo 'v1098: PREVM prepublication arms clock, preserves retry backoff and three mutants rejected PASS'
