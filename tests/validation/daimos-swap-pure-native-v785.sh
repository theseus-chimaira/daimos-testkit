#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-pure-v785.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{ echo '.text'; echo '.globl proc_swap_exchange_pure_v785'; sed -n '/^proc_swap_exchange_pure_v785:$/,/^; int proc_swap_exchange_mm_v779/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'; } > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" --name daimos-swap-pure-v785 --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" "$work/leaf.s" "$self/daimos-swap-pure-native-v785.s" > "$work/result.log" 2>&1 || { tail -35 "$work/result.log" >&2; exit 1; }
echo 'v785: native PDP-6 PURE reconstruct dispatch PASS'
