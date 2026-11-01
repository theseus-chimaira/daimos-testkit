#!/bin/sh
# Native PDP-6 DPY double MM-free refusal must retain both extents.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dpy-double-free-v912.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl dpy_write_words\n'
    sed -n '/^dpy_write_words:$/,/^dpy_putchar:$/p' \
        "$DAIMOS_REPO/system/kernel/drivers/dpy_io.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 300000 --timeout 20 \
    --workdir "$work/run" --name dpy-replace-v912 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-dpy-double-free-v912.s" > "$work/log" 2>&1 || {
        tail -50 "$work/log" >&2
        exit 1
    }
echo 'v912: native DPY double-failure ownership, retry, original replacement PASS'
