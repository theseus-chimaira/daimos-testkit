#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-metadata-v801.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
 printf '.text\n.equ PROC_TRANSITION_RH,0200000\n.globl proc_swap_exchange_records_v786\n.globl proc_swap_exchange_account_v787\n.globl proc_swap_exchange_publish_v788\n'
 sed -n '/^proc_swap_exchange_records_v786:$/,/^; Commit a prepared, already-transferred exchange/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
} > "$work/leaves.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" --name metadata-v801 --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" "$work/leaves.s" "$DAIMOS_REPO/system/kernel/proc/proc_storage_runtime_v30.s" "$self/daimos-swap-metadata-native-v801.s" > "$work/log" 2>&1 || { tail -35 "$work/log" >&2; exit 1; }
echo 'v801: native PDP-6 metadata commit integration PASS'
