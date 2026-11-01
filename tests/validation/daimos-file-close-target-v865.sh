#!/bin/sh
# Native KCORE close regression: explicit target table never replaces file_table.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-close-target-v865.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl file_close\n.globl file_close_all\n.globl file_close_all_at_v865\n'
    printf '.equ CTX_PC,020\n'
    printf '.equ PROC_WAIT_LH_MASK,060000\n'
    sed -n '/^file_close:$/,/^; int file_dup(int fd)/p' \
        "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" | sed '$d'
    sed -n '/^file_close_all:$/,/^; Shared bulk-word/p' \
        "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" | sed '$d'
    printf '.globl proc_event_apply\n.equ PROC_FILE_TABLE_OFFSET,026\n.equ PROC_FDCTL_OFFSET,024\n.equ PROC_FATAL_CLOSE_BIT,4\n.equ PROC_TRANSITION_RH,0200000\n.equ PROC_FINALIZE_OFFSET,067\n.equ PROC_FINALIZE_MARK_LH,0400000\n'
    printf '.equ PROC_WAIT_EVENT_LH,020000\n'
    sed -n '/^proc_event_apply:$/,/^proc_event_nonfatal:/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 200000 --timeout 20 \
    --workdir "$work/run" --name close-target-v865 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-file-close-target-v865.s" > "$work/log" 2>&1 || {
        tail -45 "$work/log" >&2; exit 1;
    }
echo 'v865: native explicit-target close and global pointer isolation PASS'
