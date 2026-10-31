#!/bin/sh
# v886: Execute the real PROCCTL UUO op-dispatch, not only its leaf.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-teardown-dispatch-v886.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_control\n'
    printf '.equ PROC_STATE_LH_MASK,0700000\n'
    printf '.equ PROC_FDCTL_OFFSET,024\n.equ PROC_FATAL_CLOSE_BIT,4\n'
    printf '.equ PROC_TRANSITION_RH,0200000\n.equ PROC_FINALIZE_OFFSET,067\n'
    printf '.equ PROC_FINALIZE_MARK_LH,0400000\n'
    sed -n '/^proc_control:$/,/^proc_control_getpgrp:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
    for op in getpgrp getsession getdomain newsession newdomain getevents \
        event_pid event_pgrp gettty tty_attach tty_detach tty_getfg \
        tty_setfg getuid getgid setuid setgid tty_getmode tty_setmode \
        isatty umask; do
        printf 'proc_control_%s: jrst kret_neg1\n' "$op"
    done
    printf '.data\n.globl proc_current_slot\nproc_current_slot: .word 1\n'
    printf '.globl proc_current_ptr\nproc_current_ptr: .word 0\n'
} > "$work/dispatch.s"
sed 's/ pushj 17,proc_control_getteardown_v886/ movei 1,041\
 pushj 17,proc_control/' "$self/daimos-teardown-query-v886.s" > "$work/fixture.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 150000 --timeout 20 \
    --workdir "$work/run" --name teardown-dispatch-v886 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/dispatch.s" \
    "$work/fixture.s" > "$work/log" 2>&1 || {
        tail -50 "$work/log" >&2
        exit 1
    }
echo 'v886: real PROCCTL op 041 dispatch, normal/FILE/MM/invalid query and no leak PASS'
