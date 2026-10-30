#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/swap-live-v797.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{ printf '.text\n.equ PROC_TRANSITION_RH,0200000\n.equ PROC_UAREA_RH,0400000\n.equ PROC_SWAP_BACKING_OFFSET,0406\n.equ PROC_SWAP_TEXT_SHIFT,026\n.equ PROC_SWAP_TEXT_MASK,037777\n.equ EXEC_USER_ORIGIN,020\n.globl proc_swap_exchange_live_v794\n'; sed -n '/^proc_swap_exchange_live_v794:$/,/^; int proc_swap_exchange_preflight_v791/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'; sed -n '/^backstore_verify_allocated_v795:$/,/^; int backstore_extend(first,old_blocks,new_blocks)/p' "$DAIMOS_REPO/system/kernel/storage/backstore.s" | sed '$d'; sed -n '/^proc_swap_skip_words:$/,/^\.if PROC_SWAP_VERIFY_PURE/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'; }  > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" --name swap-live-v797 --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" "$work/leaf.s" "$DAIMOS_REPO/system/kernel/proc/proc_storage_runtime_v30.s" "$self/daimos-swap-live-native-v797.s" > "$work/log" 2>&1 || { tail -30 "$work/log" >&2; exit 1; }
echo 'v797: PDP-6 live process-state and disk-record validation PASS'
