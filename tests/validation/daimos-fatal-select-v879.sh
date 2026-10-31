#!/bin/sh
# Native PDP-6 scheduler: VM-less fatal executive continuation remains runnable.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-fatal-select-v879.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_sched_resched_select\n'
    sed -n '/^        \.equ    PROC_WORDS,3$/,/^        \.text$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"
    sed -n '/^proc_sched_resched_select:$/,/^\/\*\*$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 250000 --timeout 20 \
    --workdir "$work/run" --name fatal-select-v879 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-fatal-select-v879.s" > "$work/log" 2>&1 || {
        tail -40 "$work/log" >&2
        exit 1
    }
echo 'v879: native VM-less fatal cleanup selection, RT and swap exclusion PASS'
