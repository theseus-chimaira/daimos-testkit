#!/bin/sh
# Native PDP-6 production compactor: type, pin, and candidate selection.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-mm-compact-v535.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
{
 printf '%s\n' '.text' '.globl mm_compact' \
   '.equ MM_TYPE_PROCESS,1' '.equ MM_ALLOC_LOW,0' \
   '.equ VM_EXTENT_ALIGN_WORDS,02000'
 sed -n '/^mm_compact:/,/^; int mm_alloc(words,type,owner,preference,basep)/p' \
   "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
} > "$work/production.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
 --start 1000 --step-limit 100000 --timeout 20 --workdir "$work/run" \
 --name daimos-mm-compact-dispatch-v535 --expect __test_exit=0 \
 "$self/daimos-test-crt0-v1.s" \
 "$self/daimos-mm-compact-dispatch-v535.s" "$work/production.s" >/dev/null
echo 'daimos-mm-compact-dispatch-v535: PASS (invalid, pinned/type exclusion, move-to-fit)'
