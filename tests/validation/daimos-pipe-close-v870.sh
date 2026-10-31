#!/bin/sh
# Native PDP-6 regression: pipe close is retry-safe after failed MM release.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-pipe-close-v870.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl file_close_entry_v865\n'
    sed -n '/^file_close_entry_v865:$/,/^; int file_dup(int fd)/p' \
        "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" | sed '$d'
    printf '.globl pipe_fifo_unlink_object\n'
    sed -n '/^pipe_fifo_unlink_object:$/,/^; kword_t pipe_create/p' \
        "$DAIMOS_REPO/system/kernel/ipc/pipe.s" | sed '$d'
    printf '.globl pipe_close_ref\n'
    sed -n '/^pipe_close_ref:$/,/^[[:space:]]*\.bss$/p' \
        "$DAIMOS_REPO/system/kernel/ipc/pipe.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 250000 --timeout 20 \
    --workdir "$work/run" --name pipe-close-v870 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-pipe-close-v870.s" > "$work/log" 2>&1 || {
        tail -45 "$work/log" >&2
        exit 1
    }
echo 'v870: native transactional final PIPE close and failed-MM retry PASS'
