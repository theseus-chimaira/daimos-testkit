#!/bin/sh
# Shared source-linked helper for isolated finalization or event gates.
set -eu
: "${DAIMOS_REPO:?}"
printf '\n.text\n.globl proc_exec_stack_busy_v1937\n'
sed -n '/^proc_exec_stack_busy_v1937:$/,/^; Release exactly this stack record/p' \
    "$DAIMOS_REPO/system/kernel/proc/proc_pure_backing_pdp6.s" | sed '$d'
printf '\n.bss\n.globl proc_exec_resv_head_v1933\nproc_exec_resv_head_v1933: .block 1\n.text\n'
