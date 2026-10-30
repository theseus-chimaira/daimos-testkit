#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-run-integrated-v812.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
 printf '.text\n.equ MM_TYPE_PROCESS,1\n.equ MM_PIN_FIELD,03770000000\n.equ MM_PIN_ONE,010000000\n.equ PROC_TRANSITION_RH,0200000\n.globl mm_process_shrink_pinned\n.globl mm_process_transfer_pinned\n.globl mm_unpin\n.globl proc_swap_exchange_stage_v784\n.globl proc_swap_exchange_run_v790\n.globl proc_swap_exchange_commit_v789\n.globl proc_swap_exchange_mm_v779\n.globl proc_swap_exchange_pure_v785\n.globl proc_swap_exchange_records_v786\n.globl proc_swap_exchange_account_v787\n.globl proc_swap_exchange_publish_v788\n'
 sed -n '/^proc_swap_exchange_records_v786:$/,/^; Commit a prepared, already-transferred exchange/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
 sed -n '/^proc_swap_exchange_run_v790:$/,/^; Validate live process storage before any irreversible exchange/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
 sed -n '/^proc_swap_exchange_preflight_v791:$/,/^; int proc_swap_exchange_mm_v779/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
 sed -n '/^proc_swap_exchange_live_v794:$/,/^; int proc_swap_exchange_backing_v797/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
 sed -n '/^backstore_verify_allocated_v795:$/,/^; int backstore_extend(first,old_blocks,new_blocks)/p' "$DAIMOS_REPO/system/kernel/storage/backstore.s" | sed '$d'
 sed -n '/^mm_process_verify_pinned_v792:$/,/^; Only a process extent pinned exactly once/p' "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
 sed -n '/^proc_swap_exchange_commit_v789:$/,/^; int proc_swap_exchange_run_v790/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
 sed -n '/^proc_swap_exchange_mm_v779:$/,/^; int proc_swap_exchange_prepare_ram_v780/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
 sed -n '/^proc_swap_exchange_pure_v785:$/,/^; int proc_swap_exchange_records_v786/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
 sed -n '/^proc_swap_exchange_sector_v771:$/,/^; int proc_swap_exchange_stage_v784/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
 sed -n '/^proc_swap_exchange_stage_v784:$/,/^; int proc_swap_exchange_pure_v785/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
 sed -n '/^proc_swap_exchange_prepare_ram_v780:$/,/^proc_swap_skip_words:$/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
 sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
 sed -n '/^mm_process_transfer_pinned:$/,/^; int mm_process_shrink_pinned/p' "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
 sed -n '/^mm_process_shrink_pinned:$/,/^; int mm_process_grow_pinned/p' "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
 sed -n '/^mm_pin_adjust:$/,/^        .bss/p' "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'
 sed -n '/^backstore_free:$/,/^        \.bss/p' "$DAIMOS_REPO/system/kernel/storage/backstore.s" | sed '$d'
} > "$work/leaves.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" --name run-integrated-v812 --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" "$work/leaves.s" "$DAIMOS_REPO/system/kernel/proc/proc_storage_runtime_v30.s" "$self/daimos-swap-run-integrated-v812.s" > "$work/log" 2>&1 || { tail -35 "$work/log" >&2; exit 1; }
echo 'v812: native PDP-6 metadata commit integration PASS'
