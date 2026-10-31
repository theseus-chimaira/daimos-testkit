#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-run-v790.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
 echo '.text'
 echo '.equ PROC_TRANSITION_RH,0200000'
 echo '.globl proc_swap_exchange_run_v790'
 # The isolated ordering test supplies its own preflight/live stubs.
 # Stop before their implementation; the v819 integration test exercises
 # the real preflight and live-state validation implementations.
 sed -n '/^proc_swap_exchange_run_v790:$/,/^; Validate live process storage before any irreversible exchange/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" --name swap-run-v790 --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" "$work/leaf.s" "$self/daimos-swap-run-native-v790.s" > "$work/result.log" 2>&1 || { tail -30 "$work/result.log" >&2; exit 1; }
echo 'v790: native PDP-6 stage and commit integration PASS'
