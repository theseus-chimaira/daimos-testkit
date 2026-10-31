#!/bin/sh
# PDP-6 native: Type 340 list release preserves its owner on MM failure.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dpy-close-v871.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl file_close_entry_v865\n.globl dpy_close_words_call\n'
    sed -n '/^file_close_entry_v865:$/,/^; int file_dup(int fd)/p' \
        "$DAIMOS_REPO/system/kernel/fs/file_runtime.s" | sed '$d'
    printf '.globl dpy_list_stop\n'
    sed -n '/^dpy_list_stop:$/,/^\* @brief Update the retained Type-342/p' \
        "$DAIMOS_REPO/system/kernel/drivers/dpy_io.s" |
        sed '/^\/\*\*$/,$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 250000 --timeout 20 \
    --workdir "$work/run" --name dpy-close-v871 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-dpy-close-v871.s" > "$work/log" 2>&1 || {
        tail -45 "$work/log" >&2
        exit 1
    }
echo 'v871: native DPY absent/failed/successful release PASS'
