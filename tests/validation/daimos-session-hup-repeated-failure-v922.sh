#!/bin/sh
# Native PDP-6: session HUP retry skips only irrevocably finalized members.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-session-hup-pending-v922.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" \
    "$work/leaf.s" "${DAIMOS_V922_NEGATIVE:-0}" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
start = source.index('proc_session_teardown:\n')
end = source.index('        .globl  proc_event_send\n', start)
fragment = source[start:end]
if sys.argv[3] == '1':
    # Isolated old behavior: delivered HUP is retried while MM finalizes it.
    a = fragment.index('        ; A previous HUP may have committed')
    b = fragment.index('proc_session_teardown_deliver_v905:\n', a)
    fragment = fragment[:a] + fragment[b + len('proc_session_teardown_deliver_v905:\n'):]
header = '''.text
.globl proc_session_teardown
.equ PROC_WORDS,3
.equ PROC_FDCTL_OFFSET,024
.equ PROC_FINALIZE_OFFSET,067
.equ PROC_FINALIZE_MARK_LH,0400000
.equ PROC_TRANSITION_RH,0200000
'''
Path(sys.argv[2]).write_text(header + fragment)
PY
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 250000 --timeout 25 \
    --workdir "$work/run" --name session-hup-pending-v922 \
    --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
    "$work/leaf.s" "$self/daimos-session-hup-repeated-failure-v922.s" \
    > "$work/log" 2>&1 || {
        tail -60 "$work/log" >&2
        exit 1
    }
echo 'v922: native PDP-6 repeated partial HUP refuses, TTY retained, pending owner skipped PASS'
