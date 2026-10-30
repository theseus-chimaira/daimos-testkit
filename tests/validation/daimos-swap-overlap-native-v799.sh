#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-overlap-v799.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{ printf '.text\n.globl proc_swap_exchange_overlap_v772\n'; sed -n '/^proc_swap_exchange_overlap_v772:$/,/^; int proc_swap_exchange_tails_v773/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'; } > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" --name overlap-v799 --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" "$work/leaf.s" "$self/daimos-swap-overlap-native-v799.s" > "$work/log" 2>&1 || { tail -25 "$work/log" >&2; exit 1; }
echo 'v799: native PDP-6 multi-sector overlapping exchange PASS'
