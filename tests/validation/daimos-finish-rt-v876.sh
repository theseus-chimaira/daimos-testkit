#!/bin/sh
# PDP-6 native: HUP/VM rollback preserves RT owner and transition state.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-finish-rt-v876.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_finish_slot\n'
    printf '.equ PROC_WORDS,3\n.equ PROC_FDCTL_OFFSET,024\n'
    printf '.equ PROC_FILE_TABLE_OFFSET,026\n.equ PROC_TRANSITION_RH,0200000\n'
    printf '.equ PROC_FINALIZE_OFFSET,067\n.equ PROC_FINALIZE_MARK_LH,0400000\n'
    sed -n '/^proc_finish_slot:$/,/^proc_finish_service_v881:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 250000 --timeout 20 \
    --workdir "$work/run" --name finish-rt-v876 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-finish-rt-v876.s" > "$work/log" 2>&1 || {
        tail -45 "$work/log" >&2
        exit 1
    }
echo 'v876: native RT owner/transition rollback after HUP and VM failures PASS'
