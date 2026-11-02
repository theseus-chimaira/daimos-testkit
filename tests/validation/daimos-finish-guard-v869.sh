#!/bin/sh
# PDP-6 native test: no process-finalization side effects with live FILE FDs.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-finish-guard-v869.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_finish_slot\n'
    printf '.equ PROC_WORDS,3\n.equ PROC_FDCTL_OFFSET,024\n'
    printf '.equ PROC_FILE_TABLE_OFFSET,026\n.equ PROC_TRANSITION_RH,0200000\n'
    printf '.equ PROC_FINALIZE_OFFSET,067\n.equ PROC_FINALIZE_MARK_LH,0400000\n.equ PROC_FINALIZE_PREVM_LH,0100000\n'
    printf '.equ PROC_FATAL_CLOSE_BIT,4\n'
    printf '.equ CTX_PC,020\n'
    printf '.equ PROC_WAIT_LH_MASK,060000\n'
    sed -n '/^proc_finish_slot:$/,/^proc_finish_service_v881:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 250000 --timeout 20 \
    --workdir "$work/run" --name finish-guard-v869 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-finish-guard-v869.s" > "$work/log" 2>&1 || {
        tail -45 "$work/log" >&2
        exit 1
    }
echo 'v869: native process-finalization FD invariant PASS'
