#!/bin/sh
# Host-native test of the actual C swap-detach ownership transition.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-vm-detach-order-v957.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
inc=""
for d in boot core drivers fs ipc mm modules proc storage; do
    inc="$inc -I$DAIMOS_REPO/system/kernel/$d"
done
# The test only keeps the proc_swap_detach section; unrelated swap-in/out
# sections are discarded, including their filesystem and memory references.
# shellcheck disable=SC2086
cc -std=c99 -O2 -ffunction-sections -fdata-sections \
    -DPROC_SWAP_TRANSACTIONS_PDP6_ASM -DPROC_SWAP_SERVICE_PDP6_ASM \
    $inc -I"${PDP10_PREFIX:-$HOME/cross}/include" \
    -c "$DAIMOS_REPO/system/kernel/proc/vm_pdp6_swap.c" -o "$work/swap.o"
# shellcheck disable=SC2086
cc -std=c99 -O2 -ffunction-sections -fdata-sections \
    $inc -I"${PDP10_PREFIX:-$HOME/cross}/include" \
    -Wl,--gc-sections "$self/daimos-vm-detach-order-v957.c" \
    "$work/swap.o" -o "$work/test"
"$work/test"
echo 'v957: actual C resident-vs-disk swap-detach branch contract PASS'
