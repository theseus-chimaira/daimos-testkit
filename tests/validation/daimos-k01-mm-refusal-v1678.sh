#!/bin/sh
# Production MM compactor refusing physically unavailable moves (PDP-6).
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-mm-refusal-v1678.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

{
    printf '%s\n' '.text' '.globl mm_compact' \
        '.equ MM_TYPE_PROCESS,1' '.equ MM_ERR_BUSY,-5' \
        '.equ MM_ERR_DESCRIPTORS,-3' '.equ MM_ERR_FRAGMENTED,-2' \
        '.equ MM_ALLOC_LOW,0' '.equ VM_EXTENT_ALIGN_WORDS,02000'
    sed -n '/^mm_compact:/,/^; int mm_alloc(words,type,owner,preference,basep)/p' \
        "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
} > "$work/production.s"

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 100000 \
    --timeout 25 --workdir "$work/run" \
    --name daimos-k01-mm-refusal-v1678 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-k01-mm-refusal-v1678.s" "$work/production.s" >/dev/null
echo 'K01 v1678: MM_BUSY and MM_INVAL preserved, alternate move, fragmentation, NOMEM and owner identity PASS'
