#!/bin/sh
# Native PDP-6 compaction -> MM move -> real VM, FS copy and runqueue.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-mm-apr-handoff-v540.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
{
 printf '%s\n' '.text' '.globl mm_compact' '.globl vm_extent_move' '.globl vm_activate_current' '.globl mm_extent_insert' '.globl fs_move_words' '.globl proc_runq_add' '.globl proc_runq_remove' \
  '.equ MM_TYPE_PROCESS,1' '.equ MM_ALLOC_LOW,0' '.equ MM_ALLOC_HIGH,1' '.equ VM_EXTENT_ALIGN_WORDS,02000' \
  '.equ PROC_STATE_LH_MASK,0700000' '.equ PROC_STATE_RUN,0200000'
 sed -n '/^mm_delete:/,/^; int mm_alloc_aligned_noreclaim/p' "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
 sed -n '/^mm_move_extent:/,/^; int mm_alloc(words,type,owner,preference,basep)/p' "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
 sed -n '/^vm_activate_current:/,/^        popj    17,/p' "$DAIMOS_REPO/system/kernel/proc/vm_pdp6.s"
 sed -n '/^vm_extent_move:/,/^\/\*\*/p' "$DAIMOS_REPO/system/kernel/proc/vm_pdp6.s" | sed '$d'
 sed -n '/^fs_copy_words:/,/^        \.globl  fs_zero_words/p' "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" | sed '$d'
 sed -n '/^proc_runq_add:/,/^\/\*\*/p' "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
 printf '%s\n' '.data' '.globl kconst_6_6' 'kconst_6_6: .word 6,,6'
} > "$work/production.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step --start 1000 \
 --step-limit 300000 --timeout 25 --workdir "$work/run" --name daimos-mm-apr-handoff-v540 \
 --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
 "$self/daimos-mm-apr-handoff-v540.s" "$work/production.s" >/dev/null
printf '%s\n' 'daimos-mm-apr-handoff-v540: PASS (production compaction, VM, FS move, runqueue)'
