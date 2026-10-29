#!/bin/sh
# Execute actual swap-out unpin failure branches on PDP-6.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-unpin-native-v667.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
src=$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s
{
    echo '.text'
    echo '.globl postwrite_unpin_probe'
    echo '.globl rollback_unpin_probe'
    echo 'postwrite_unpin_probe:'
    awk '
      /movem   16,PROC_SWAP_BACKING_OFFSET\(1\)/ {on=1; next}
      on && /move    1,13/ {start=1}
      on && start {print}
      on && start && /jumpn   1,proc_swap_storage_invariant_v30/ {exit}
    ' "$src"
    echo 'setz 1,'
    echo 'popj 17,'
    echo 'rollback_unpin_probe:'
    sed -n '/^proc_swap_out_unpin:$/,/^proc_swap_out_record_fail:$/p' "$src" |
       sed '1d;$d'
    echo 'setz 1,'
    echo 'popj 17,'
} > "$work/branches.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
  --start 1000 --step-limit 100000 --timeout 20 \
  --workdir "$work/run" --name daimos-swap-unpin-native-v667 \
  --expect __test_exit=0 \
  "$self/daimos-test-crt0-v1.s" "$work/branches.s" \
  "$self/daimos-swap-unpin-native-v667.s" > "$work/result.log" 2>&1 || {
    tail -40 "$work/result.log" >&2; exit 1;
  }
echo 'daimos-swap-unpin-native-v667: PASS'
