#!/bin/sh
# Check native transaction result classifications without exercising PI scheduling.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-mm-swap-result-v756.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
src="$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s"
{ printf '.equ PROC_SWAP_VERIFY_PURE,0\n'; cat "$src"; } > "$work/swap.s"
"$PDP10_PREFIX/bin/das" -C -F -O "$work/swap.dobj" "$work/swap.s"
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -t "$work/swap.dobj" > "$work/symbols"
grep -q 'proc_swap_in' "$work/symbols"
# The numeric result contract is shared by the C and native assembly paths.
grep -q '^#define PROC_SWAP_IN_PRESSURE[[:space:]]*1$' "$DAIMOS_REPO/system/kernel/proc/proc_swap.h"
grep -q 'rc >= MM_ERR_DESCRIPTORS' "$DAIMOS_REPO/system/kernel/proc/vm_pdp6_swap.c"
grep -q 'jumpn[[:space:]]*7,proc_swap_in_pressure' "$src"
echo 'v756: swap-in typed-result contract compiles and paths agree (not recovery acceptance)'
