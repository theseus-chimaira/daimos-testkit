#!/bin/sh
# Native PDP-6 regression for current-process failed-close exit handling.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-current-exit-v868.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl file_close\n.globl file_close_all\n.globl file_close_all_at_v865\n'
    sed -n '/^file_close:$/,/^; int file_dup(int fd)/p' \
        "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" | sed '$d'
    sed -n '/^file_close_all:$/,/^; Shared bulk-word/p' \
        "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" | sed '$d'
    printf '.globl proc_event_apply\n.equ PROC_FILE_TABLE_OFFSET,026\n.equ PROC_FDCTL_OFFSET,024\n.equ PROC_FATAL_CLOSE_BIT,4\n.equ PROC_TRANSITION_RH,0200000\n.equ PROC_FINALIZE_OFFSET,067\n.equ PROC_FINALIZE_MARK_LH,0400000\n'
    sed -n '/^proc_event_apply:$/,/^proc_event_nonfatal:/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
    printf '.globl native_sys_exit_v868\n'
    sed -n '/^%L66:$/,/^%L67:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/syscall_dispatch_pdp6.s" |
        sed '$d; s/^%L66:$/native_sys_exit_v868:/'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 250000 --timeout 20 \
    --workdir "$work/run" --name current-exit-v868 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-current-exit-v868.s" > "$work/log" 2>&1 || {
        tail -45 "$work/log" >&2
        exit 1
    }
echo 'v868: current EXIT and fatal-event failed-close recovery PASS'
