#!/bin/sh
# PDP-6 executes the production post-write MM-free failure/rollback sequence.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-swap-mmfree-v668.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
src=$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s
{
  echo '.text'
  echo '.equ PROC_SWAP_BACKING_OFFSET,0406'
  echo '.equ PROC_TRANSITION_RH,0200000'
  echo '.equ MM_TYPE_PROCESS,1'
  echo '.globl swap_mmfree_failure_probe'
  echo 'swap_mmfree_failure_probe:'
  sed -n '/^[[:space:]]*movem   16,PROC_SWAP_BACKING_OFFSET(1)$/,/^proc_swap_out_restore:$/p' "$src" |
    sed -e '/^proc_swap_out_restore:$/,$d'
  echo 'proc_swap_out_restore:'
  echo 'jrst probe_restored'
} > "$work/txn.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
    --start 1000 --step-limit 200000 --timeout 20 \
    --workdir "$work/run" --name daimos-swap-mmfree-v668 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/txn.s" \
    "$DAIMOS_REPO/system/kernel/core/ret.s" \
    "$self/daimos-swap-mmfree-native-v668.s" > "$work/result.log" 2>&1 || {
      tail -30 "$work/result.log" >&2; exit 1;
    }
echo 'daimos-swap-mmfree-native-v668: PASS'
