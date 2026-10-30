#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/swap-live-v796.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{ printf '.text\n.equ PROC_TRANSITION_RH,0200000\n.globl proc_swap_exchange_live_v794\n'; sed -n '/^proc_swap_exchange_live_v794:$/,/^; int proc_swap_exchange_preflight_v791/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'; sed -n '/^backstore_verify_allocated_v795:$/,/^; int backstore_extend(first,old_blocks,new_blocks)/p' "$DAIMOS_REPO/system/kernel/storage/backstore.s" | sed '$d'; } > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" --name swap-live-v796 --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" "$work/leaf.s" "$DAIMOS_REPO/system/kernel/proc/proc_storage_runtime_v30.s" "$self/daimos-swap-live-native-v796.s" > "$work/log" 2>&1 || { tail -30 "$work/log" >&2; exit 1; }
echo 'v796: PDP-6 live process-state and disk-record validation PASS'
