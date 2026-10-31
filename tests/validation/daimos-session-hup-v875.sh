#!/bin/sh
# PDP-6 native session-leader teardown: TTY commit after successful HUPs.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-session-hup-v875.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_session_teardown\n'
    printf '.equ PROC_WORDS,3\n.equ PROC_FDCTL_OFFSET,024\n'
    sed -n '/^proc_session_teardown:$/,/^        \.globl  proc_event_send$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 250000 --timeout 20 \
    --workdir "$work/run" --name session-hup-v875 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-session-hup-v875.s" > "$work/log" 2>&1 || {
        tail -45 "$work/log" >&2
        exit 1
    }
echo 'v875: native session HUP failure retention and successful TTY detach PASS'
