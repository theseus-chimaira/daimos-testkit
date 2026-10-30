#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-prepare-v781.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
 echo '.text'
 echo '.globl proc_swap_exchange_prepare_v781'
 sed -n '/^proc_swap_exchange_prepare_v781:$/,/^\/\* Return the complete/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
 --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" \
 --name daimos-swap-prepare-v781 --expect __test_exit=0 \
 "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
 "$self/daimos-swap-prepare-native-v781.s" > "$work/result.log" 2>&1 || {
 tail -35 "$work/result.log" >&2; exit 1;
 }
echo 'v781: native PDP-6 swap reservation rollback PASS'
