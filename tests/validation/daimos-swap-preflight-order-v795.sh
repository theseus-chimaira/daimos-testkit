#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-order-v795.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{ echo '.text'; echo '.globl proc_swap_exchange_run_v790'; sed -n '/^proc_swap_exchange_run_v790:$/,/^; Validate live process storage before/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'; } > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" --name swap-order-v795 --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" "$work/leaf.s" "$self/daimos-swap-preflight-order-v795.s" > "$work/log" 2>&1 || { tail -30 "$work/log" >&2; exit 1; }
echo 'v795: PDP-6 preflight precedes live validation PASS'
