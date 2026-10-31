#!/bin/sh
# Exercise the real resident KCORE OOM victim selector without killing jobs.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-oom-owner-v866.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_oom_select_v863\n'
    printf '.equ PROC_WORDS,3\n.equ PROC_TRANSITION_RH,0200000\n'
    printf '.equ PROC_STATE_LH_MASK,0700000\n.equ PROC_STATE_RUN,0200000\n'
    printf '.equ PROC_STATE_SLEEP,0300000\n.equ PROC_STATE_STOP,0600000\n'
    printf '.equ PROC_FDCTL_OFFSET,024\n.equ PROC_USER_MAP_BIT,2\n'
    sed -n '/^proc_oom_select_v863:$/,/^proc_swap_victim:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 200000 --timeout 20 \
    --workdir "$work/run" --name oom-owner-v866 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-oom-provider-owner-v866.s" > "$work/log" 2>&1 || {
        tail -40 "$work/log" >&2
        exit 1
    }
echo 'v866: native OOM provider-owner protection PASS (no termination)'
