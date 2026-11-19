#!/bin/sh
# Real allocator and MRES process-reclaim control flow with typed MM leaves.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-pressure-chain-v1678.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

{
    printf '%s\n' '.text' '.globl mm_alloc_aligned' \
        '.globl proc_swap_mres_reclaim_v481' \
        '.equ MM_TYPE_PROCESS,1' '.equ MM_ERR_DESCRIPTORS,-3' \
        '.equ MM_ERR_FRAGMENTED,-2' '.equ PROC_NO_SLOT,0400'
    sed -n '/^mm_alloc_aligned:/,/^; int mm_free(base,type,owner)/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
    sed -n '/^proc_swap_mres_reclaim_v481:/,$p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s"
} > "$work/production.s"

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 150000 \
    --timeout 25 --workdir "$work/run" \
    --name daimos-k01-pressure-chain-v1678 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-k01-pressure-chain-v1678.s" "$work/production.s" >/dev/null
echo 'K01 v1678: allocator/swap-chain MM_BUSY and MM_INVAL, bounded victim selection, normal fragmentation and success PASS'
