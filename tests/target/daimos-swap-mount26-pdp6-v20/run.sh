#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-swap-mount26-pdp6-v20.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)

# Exercise the exact production unpacker and immutable-backing busy leaves.
{
    printf '%s\n' '.text' '.globl proc_swap_unpack_backing' \
        '.globl proc_swap_backing_busy' '.globl proc_swap_mount_busy' \
        '.equ PROC_SWAP_TEXT_SHIFT,026' \
        '.equ PROC_SWAP_TEXT_MASK,037777' \
        '.equ PROC_SWAP_MOUNT_SHIFT,022' \
        '.equ PROC_SWAP_BACKING_OFFSET,0406'
    sed -n '/^proc_swap_unpack_backing:/,/^\/\*$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pure_backing_pdp6.s" | sed '$d'
    sed -n '/^proc_swap_backing_busy:/,$p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pure_backing_pdp6.s"
} > "$work/unpack.s"

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 100000 --timeout 15 \
    --workdir "$work/run" --name daimos-swap-mount26-pdp6-v20 \
    --expect __test_exit=0 \
    "$here/../../validation/daimos-test-crt0-v1.s" \
    "$here/test.s" "$work/unpack.s" >/dev/null
printf '%s\n' 'daimos-swap-mount26-pdp6-v20: PASS (26th mount provider, PURE text, ownership and busy protection)'
