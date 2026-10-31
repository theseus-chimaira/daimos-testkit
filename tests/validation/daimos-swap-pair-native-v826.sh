#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/swap-pair-v826.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
  echo '.text'
  echo '.globl proc_swap_exchange_pair_v826'
  echo '.equ PROC_TRANSITION_RH,0200000'
  echo '.equ PROC_UAREA_RH,0400000'
  echo '.equ PROC_SWAP_BACKING_OFFSET,0406'
  echo '.equ PROC_SWAP_TEXT_SHIFT,026'
  echo '.equ PROC_SWAP_TEXT_MASK,037777'
  echo '.equ EXEC_USER_ORIGIN,020'
  sed -n '/^proc_swap_exchange_pair_v826:$/,/^; int proc_swap_exchange_sector_v771/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
  sed -n '/^proc_swap_skip_words:$/,/^\.if PROC_SWAP_VERIFY_PURE/p' "$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" --name swap-pair-v826 --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" "$work/leaf.s" "$self/daimos-swap-pair-native-v826.s" > "$work/log" 2>&1 || { tail -40 "$work/log" >&2; exit 1; }
echo 'v826: native PDP-6 raw exchange pair eligibility PASS'
