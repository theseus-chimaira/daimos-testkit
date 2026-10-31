#!/bin/sh
# v884 native PDP-6: finite slot-0 maintenance dispatch under CPU load.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-reaper-sched-v884.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_sched_tick_select\n.globl proc_sched_resched_select\n'
    sed -n '/^        \.equ    PROC_WORDS,3$/,/^        \.text$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"
    sed -n '/^proc_sched_resched_select:$/,/^\/\*\*$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 300000 --timeout 20 \
    --workdir "$work/run" --name reaper-sched-v884 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-reaper-sched-v884.s" > "$work/log" 2>&1 || {
        tail -48 "$work/log" >&2
        exit 1
    }
echo 'v884: native user dispatch, timed slot-0 reaper, RT exemption and CPU-charge retention PASS'
