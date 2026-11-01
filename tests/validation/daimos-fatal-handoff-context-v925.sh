#!/bin/sh
# Native PDP-6 acceptance for committed non-current fatal-event delivery.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-noncurrent-fatal-v925.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_finish_slot\n.globl proc_finish_service_v881\n'
    printf '.equ PROC_WORDS,3\n.equ PROC_TRANSITION_RH,0200000\n'
    printf '.equ PROC_STATE_LH_MASK,0700000\n.equ PROC_WAIT_EVENT_LH,020000\n.equ PROC_WAIT_LH_MASK,060000\n'
    printf '.equ PROC_FILE_TABLE_OFFSET,026\n.equ PROC_FDCTL_OFFSET,024\n'
    printf '.equ PROC_FINALIZE_OFFSET,067\n.equ PROC_FINALIZE_MARK_LH,0400000\n'
    printf '.equ PROC_FATAL_CLOSE_BIT,4\n'
    printf '.equ CTX_PC,020\n'
    sed -n '/^proc_finish_slot:$/,/^proc_slot_discard:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
    printf '.globl proc_event_apply\n'
    sed -n '/^proc_event_apply:$/,/^proc_event_nonfatal:/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 450000 --timeout 20 \
    --workdir "$work/run" --name noncurrent-fatal-v925 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-fatal-handoff-context-v925.s" > "$work/log" 2>&1 || {
        tail -55 "$work/log" >&2
        exit 1
    }
echo 'v925: foreign CHILD/INTR stacks protected; normal fatal lifecycle PASS'
