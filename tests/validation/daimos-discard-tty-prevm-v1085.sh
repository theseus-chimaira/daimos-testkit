#!/bin/sh
# Actual source-linked PDP-6 RUN rollback; negative source must strand TTY.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-discard-tty-prevm-v1085.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
source_file="$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"
expect=0
if [ "${DAIMOS_V1085_NEGATIVE:-0}" = 1 ]; then
    git -C "$DAIMOS_REPO" show \
        6d55636c:system/kernel/proc/proc_pdp6.s > "$work/baseline.s"
    source_file="$work/baseline.s"
    expect=1
fi
{
    printf '.text\n.globl proc_slot_discard\n.globl proc_finish_service_v881\n'
    printf '.equ PROC_WORDS,3\n.equ PROC_TRANSITION_RH,0200000\n'
    printf '.equ PROC_STATE_LH_MASK,0700000\n'
    printf '.equ PROC_FILE_TABLE_OFFSET,026\n.equ PROC_FDCTL_OFFSET,024\n'
    printf '.equ PROC_FINALIZE_OFFSET,067\n.equ PROC_FINALIZE_MARK_LH,0400000\n'
    printf '.equ PROC_FINALIZE_PREVM_LH,0100000\n'
    printf '.equ PROC_FATAL_CLOSE_BIT,4\n.equ CTX_PC,020\n'
    printf '.equ PROC_WAIT_LH_MASK,060000\n'
    sed -n '/^proc_finish_slot:$/,/^proc_uarea_release:$/p' \
        "$source_file" | sed '$d'
} > "$work/leaf.s"

python3 - "$self/daimos-run-discard-reaper-v892.s" "$work/stubs.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
s = s[s.index('.globl vm_space_destroy\n'):]
s = s.replace('''proc_scope_id:
 setz 1,
 popj 17,''', '''proc_scope_id:
 movei 1,5
 popj 17,''', 1)
s = s.replace('''proc_tty_release_session:
 aos __tty_calls
 popj 17,''', '''proc_tty_release_session:
 aos __tty_calls
 caie 1,5
 aos __tty_bad_args_v1085
 caie 2,2
 aos __tty_bad_args_v1085
 move 1,__tty_calls
 caie 1,1
 jrst tty_accept_v1085
 seto 1,
 popj 17,
tty_accept_v1085:
 setz 1,
 popj 17,''', 1)
old = '''proc_uarea_release:
 aos __release_calls
 move 3,__release_calls
 caig 3,2
 jrst release_failed
 hrrz 3,(2)
 andi 3,0377777
 movem 3,(2)
 setz 1,
 popj 17,
release_failed:
 seto 1,
 popj 17,'''
new = '''proc_uarea_release:
 aos __release_calls
 hrrz 3,(2)
 andi 3,0377777
 movem 3,(2)
 setz 1,
 popj 17,'''
assert s.count(old) == 1
s = s.replace(old, new, 1)
s += '\n__tty_bad_args_v1085: .word 0\n'
Path(sys.argv[2]).write_text(s)
PY
cat "$self/daimos-discard-tty-prevm-v1085.s" "$work/stubs.s" \
    > "$work/test.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 450000 --timeout 25 \
    --workdir "$work/run" --name discard-tty-prevm-v1085 \
    --expect __test_exit="$expect" \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" "$work/test.s" \
    > "$work/log" 2>&1 || {
        tail -70 "$work/log" >&2
        exit 1
    }
if [ "$expect" = 0 ]; then
    echo 'v1085: rejected TTY retains RUN VM/uarea; slot-0 retries and frees once PASS'
else
    echo 'v1085: original RUN discard orphaned refused TTY after VM; negative FAIL expected'
fi
