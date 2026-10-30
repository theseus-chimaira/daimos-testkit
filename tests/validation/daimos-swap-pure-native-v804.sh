#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/swap-pure-v804.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{ printf '.text\n.globl proc_swap_exchange_pure_v785\n'; sed -n '/^proc_swap_exchange_pure_v785:$/,/^; int proc_swap_exchange_records_v786/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'; } > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" --name swap-pure-v804 --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" "$work/leaf.s" "$self/daimos-swap-pure-native-v804.s" > "$work/log" 2>&1 || { tail -30 "$work/log" >&2; exit 1; }
echo 'v804: native PDP-6 PURE prefix reconstruction PASS'
