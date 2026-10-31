#!/bin/sh
# v888: production FILE bulk close retains first exact rejecting provider return.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-file-provider-error-v888.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl file_close_all_at_v865\n.globl proc_control_getteardown_v886\n'
    sed -n '/^file_close_all_at_v865:$/,/^; Shared bulk-word I\/O validation/p' \
        "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" | sed '$d'
    printf '.equ PROC_STATE_LH_MASK,0700000\n'
    printf '.equ PROC_FDCTL_OFFSET,024\n.equ PROC_FILE_TABLE_OFFSET,026\n'
    printf '.equ PROC_FATAL_CLOSE_BIT,4\n.equ PROC_TRANSITION_RH,0200000\n'
    printf '.equ PROC_FINALIZE_OFFSET,067\n.equ PROC_FINALIZE_MARK_LH,0400000\n'
    sed -n '/^proc_control_getteardown_v886:$/,/^proc_control_getpgrp:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
    printf 'mm_uarea_probe_v887: movei 1,0400\n popj 17,\n'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 220000 --timeout 25 \
    --workdir "$work/run" --name file-provider-error-v888 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-file-provider-error-v888.s" > "$work/log" 2>&1 || {
        tail -52 "$work/log" >&2
        exit 1
    }
echo 'v888: real FILE close pass records first errno/FD, preserves handles, retries and clears witness PASS'
