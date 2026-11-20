#!/bin/sh
# Native PDP-6: real session HUP/event delivery, permanently refused FILE.
set -eu
: "$DAIMOS_REPO" "$PDP10_PREFIX"
TMPDIR=$(printenv TMPDIR || printf '%s' "$HOME/tmp")
export TMPDIR
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-k02-permanent-session-v1728.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" "$work" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
work = Path(sys.argv[2])

def section(start, end):
    assert source.count(start) == 1 and source.count(end) == 1
    return start + source.split(start, 1)[1].split(end, 1)[0]

header = '''.text
.globl proc_session_teardown
.globl proc_event_apply
.equ PROC_WORDS,3
.equ PROC_FDCTL_OFFSET,024
.equ PROC_FILE_TABLE_OFFSET,026
.equ PROC_FINALIZE_OFFSET,067
.equ PROC_FINALIZE_MARK_LH,0400000
.equ PROC_TRANSITION_RH,0200000
.equ PROC_WAIT_LH_MASK,060000
.equ PROC_WAIT_INTR_LH,060000
.equ PROC_WAIT_EVENT_LH,020000
.equ PROC_STATE_LH_MASK,0700000
.equ PROC_STATE_SLEEP,0300000
.equ PROC_FATAL_CLOSE_BIT,04
.equ CTX_PC,020
'''
text = header + section('proc_session_teardown:',
                        '        .globl  proc_event_send\n')
text += section('proc_event_apply:', 'proc_event_nonfatal:')
(work / 'leaf.s').write_text(text)

# All three negative controls must fail with the same source-linked
# test: ignoring a member close refusal, ignoring FATAL_CLOSE, and
# redelivering HUP to the already finalized VM_NONE process.
mutants = {
    'ignore-hup-refusal': (
        '        pushj   17,proc_event_apply\n'
        '        jumpn   1,proc_session_teardown_fail',
        '        pushj   17,proc_event_apply\n'
        '        jumpe   1,proc_session_teardown_fail'),
    'ignore-fatal-owner': (
        '        trne    1,PROC_FATAL_CLOSE_BIT\n'
        '        jrst    proc_event_fatal_close_busy_v879',
        '        trnn    1,PROC_FATAL_CLOSE_BIT\n'
        '        jrst    proc_event_fatal_close_busy_v879'),
    'redeliver-finalized': (
        '        tlne    6,PROC_FINALIZE_MARK_LH\n'
        '        jrst    proc_session_teardown_next',
        '        tlnn    6,PROC_FINALIZE_MARK_LH\n'
        '        jrst    proc_session_teardown_next'),
}
for name, (before, after) in mutants.items():
    assert text.count(before) == 1, ('v1728 source drift', name)
    (work / ('unsafe-' + name + '.s')).write_text(
        text.replace(before, after, 1))
PY

run_case() {
    name=$1
    leaf=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 300000 --timeout 25 \
        --workdir "$work/run-$name" --name "session-v1728-$name" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" "$leaf" \
        "$self/daimos-k02-permanent-session-v1728.s" \
        > "$work/log-$name" 2>&1
}

if ! run_case positive "$work/leaf.s"; then
    tail -65 "$work/log-positive" >&2
    exit 1
fi
for mutant in ignore-hup-refusal ignore-fatal-owner redeliver-finalized; do
    if run_case "$mutant" "$work/unsafe-$mutant.s"; then
        echo "v1728: unsafe mutation passed: $mutant" >&2
        exit 1
    fi
done
echo 'v1728: eight refused session HUPs retain TTY/FD6, skip finalized member; 3 unsafe mutants rejected PASS'
