#!/bin/sh
# v887: Native PDP-6 provider-specific read-only teardown detail.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-teardown-detail-v887.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_control_getteardown_v886\n'
    printf '.equ PROC_STATE_LH_MASK,0700000\n'
    printf '.equ PROC_FDCTL_OFFSET,024\n.equ PROC_FILE_TABLE_OFFSET,026\n'
    printf '.equ PROC_FATAL_CLOSE_BIT,4\n.equ PROC_TRANSITION_RH,0200000\n'
    printf '.equ PROC_FINALIZE_OFFSET,067\n.equ PROC_FINALIZE_MARK_LH,0400000\n'
    sed -n '/^proc_control_getteardown_v886:$/,/^proc_control_getpgrp:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
    sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^mm_uarea_probe_v887:$/,/^; Find a fitting free gap/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 180000 --timeout 25 \
    --workdir "$work/run" --name teardown-detail-v887 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-teardown-detail-v887.s" > "$work/log" 2>&1 || {
        tail -50 "$work/log" >&2
        exit 1
    }
echo 'v887: FILE provider/count/first FD and MM extent pins/owner/type/missing snapshots PASS'
