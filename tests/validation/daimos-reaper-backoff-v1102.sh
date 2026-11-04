#!/bin/sh
# Source-linked PDP-6 active reaper retry protocol, with unsafe mutations.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-reaper-backoff-v1102.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" "$work" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1]).read_text()
work = Path(sys.argv[2])

def section(first, last):
    assert src.count(first) == 1 and src.count(last) == 1
    return first + src.split(first, 1)[1].split(last, 1)[0]

header = ('.text\n.equ PROC_WORDS,3\n'
          '.equ PROC_TRANSITION_RH,0200000\n'
          '.equ PROC_STATE_LH_MASK,0700000\n'
          '.equ PROC_FINALIZE_OFFSET,067\n'
          '.equ PROC_FINALIZE_MARK_LH,0400000\n'
          '.equ PROC_FINALIZE_PREVM_LH,0100000\n'
          '.equ PROC_TIMER_CLOCK_MASK,0377777\n'
          '.globl proc_finish_service_v881\n'
          '.globl proc_finish_mark_pending_v892\n'
          '.globl proc_finish_backoff_advance_v885\n')
text = header + section('proc_finish_mark_pending_v892:',
                        'proc_finish_fail:')
text += section('proc_finish_service_v881:',
                '/**\n * @brief Discard an uncommitted RUN slot')
text += section('proc_finish_backoff_advance_v885:', '\n        .bss')
assert 'proc_finish_service_failed_v1102:' in text
assert 'proc_finish_service_pending_v1102:' in text

# The interrupt-masked idle caller must not clear the pending bit before
# service. It used to make every failed finalizer reset the delay to 020.
idle = section('proc_idle_loop:', 'proc_idle_loop_end:')
def preserves_pending_during_scan(body):
    assert body.count('pushj   17,proc_finish_service_v881') == 1
    before = body.split('pushj   17,proc_finish_service_v881', 1)[0]
    return 'andcam  4,proc_finish_last_tick_v881' not in before

assert preserves_pending_during_scan(idle)
# A fourth negative control reinstates the old idle-loop bit clear.
# The source closure check must reject the original v1098 regression.
unsafe_idle = idle.replace(
    '        pushj   17,proc_finish_service_v881',
    '        movsi   4,0400000\n'
    '        andcam  4,proc_finish_last_tick_v881\n'
    '        pushj   17,proc_finish_service_v881', 1)
assert not preserves_pending_during_scan(unsafe_idle)
assert 'proc_finish_backoff_advance_v885' in idle
(work / 'leaf.s').write_text(text)

mutants = {
    'ignore-failure': (
        '        trne    11,2\n        jrst    proc_finish_service_pending_v1102',
        '        trnn    11,2\n        jrst    proc_finish_service_pending_v1102'),
    'reset-on-failure': (
        '        tlne    5,0400000\n        jrst    proc_finish_rearm_v885',
        '        tlnn    5,0400000\n        jrst    proc_finish_rearm_v885'),
    'false-completion': (
        'proc_finish_service_return_v881:\n        move    1,11',
        'proc_finish_service_return_v881:\n        movei   1,1'),
}
for name, (old, new) in mutants.items():
    assert text.count(old) == 1, (name, 'anchor drift')
    (work / ('unsafe-' + name + '.s')).write_text(text.replace(old, new, 1))
PY
run_case() {
    name=$1
    leaf=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 100000 --timeout 20 \
        --workdir "$work/run-$name" --name "reaper-v1102-$name" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" "$leaf" \
        "$self/daimos-reaper-backoff-v1102.s" >"$work/log-$name" 2>&1
}
if ! run_case positive "$work/leaf.s"; then
    tail -65 "$work/log-positive" >&2
    exit 1
fi
for mutant in ignore-failure reset-on-failure false-completion; do
    if run_case "$mutant" "$work/unsafe-$mutant.s"; then
        echo "v1102: unsafe $mutant mutation PASSED" >&2
        exit 1
    fi
done
echo 'v1102: shared retry backoff 16/32/64, owner commit, four unsafe mutants rejected PASS'
