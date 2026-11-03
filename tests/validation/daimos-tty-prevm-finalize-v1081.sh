#!/bin/sh
# Source-link real process finalizer; only the MM/TTY witnesses are stubs.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-tty-prevm-finalize-v1081.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
proc_source=${PROC_SOURCE_V1081:-$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s}
{
    printf '.text\n.globl proc_finish_slot\n.globl proc_finish_service_v881\n'
    printf '.equ PROC_WORDS,3\n.equ PROC_TRANSITION_RH,0200000\n'
    printf '.equ PROC_STATE_LH_MASK,0700000\n'
    printf '.equ PROC_FILE_TABLE_OFFSET,026\n.equ PROC_FDCTL_OFFSET,024\n'
    printf '.equ PROC_FINALIZE_OFFSET,067\n.equ PROC_FINALIZE_MARK_LH,0400000\n'
    printf '.equ PROC_FINALIZE_PREVM_LH,0100000\n'
    printf '.equ PROC_FATAL_CLOSE_BIT,4\n.equ CTX_PC,020\n'
    printf '.equ PROC_WAIT_LH_MASK,060000\n'
    sed -n '/^proc_finish_slot:$/,/^proc_slot_discard:$/p' \
        "$proc_source" | sed '$d'
} > "$work/leaf.s"
# Reuse the well-tested v881 MM/VM/HUP fixture, overriding only its
# TTY oracle to refuse the first call before VM teardown.
python3 - "$self/daimos-deferred-uarea-v881.s" "$work/stubs.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
s = s[s.index('.globl proc_session_teardown\n'):]
old = '''proc_tty_release_session:
 aos __tty_calls
 setz 1,
 popj 17,'''
new = '''proc_tty_release_session:
 aos __tty_calls
 move 1,__tty_calls
 caie 1,1
 jrst tty_accept_v1081
 seto 1,
 popj 17,
tty_accept_v1081:
 setz 1,
 popj 17,'''
assert s.count(old) == 1
Path(sys.argv[2]).write_text(s.replace(old, new, 1))
PY
cat "$self/daimos-tty-prevm-finalize-v1081.s" "$work/stubs.s" > "$work/fixture.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 350000 --timeout 20 \
    --workdir "$work/run" --name tty-prevm-finalize-v1081 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$work/fixture.s" \
    > "$work/log" 2>&1 || {
        tail -55 "$work/log" >&2
        exit 1
    }
echo 'v1081: refused TTY keeps VM; PREVM, VM and uarea retries commit once PASS'
