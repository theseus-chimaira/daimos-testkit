#!/bin/sh
# v886: Native PDP-6 read-only teardown status from existing process ownership.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-teardown-query-v886.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_control_getteardown_v886\n'
    printf '.equ PROC_STATE_LH_MASK,0700000\n'
    printf '.equ PROC_FDCTL_OFFSET,024\n.equ PROC_FATAL_CLOSE_BIT,4\n'
    printf '.equ PROC_TRANSITION_RH,0200000\n.equ PROC_FINALIZE_OFFSET,067\n'
    printf '.equ PROC_FINALIZE_MARK_LH,0400000\n'
    sed -n '/^proc_control_getteardown_v886:$/,/^proc_control_getpgrp:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 120000 --timeout 20 \
    --workdir "$work/run" --name teardown-query-v886 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-teardown-query-v886.s" > "$work/log" 2>&1 || {
        tail -45 "$work/log" >&2
        exit 1
    }
echo 'v886: read-only teardown diagnosis, invalid/FREE rejection, FILE/MM stages, retry cap and no address leak PASS'
