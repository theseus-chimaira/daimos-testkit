#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-swap-mount16-pdp6-v10.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)

# The unpacker is taken verbatim from the production native assembly. Other
# swap routines have unrelated dependencies, so isolate the exact tested leaf.
{
    printf '%s\n' '.text' '.globl proc_swap_unpack_backing' \
        '.equ PROC_SWAP_TEXT_SHIFT,026' \
        '.equ PROC_SWAP_TEXT_MASK,037777' \
        '.equ PROC_SWAP_MOUNT_SHIFT,022'
    sed -n '/^proc_swap_unpack_backing:/,/^\/\*$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pure_backing_pdp6.s" | sed '$d'
} > "$work/unpack.s"

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 100000 --timeout 15 \
    --workdir "$work/run" --name daimos-swap-mount16-pdp6-v10 \
    --expect __test_exit=0 \
    "$here/../../validation/daimos-test-crt0-v1.s" \
    "$here/test.s" "$work/unpack.s" >/dev/null
printf '%s\n' 'daimos-swap-mount16-pdp6-v10: PASS (16th mount provider reconstruction and missing-root rejection)'
