#!/bin/sh
# Native PDP-6 source-linked sleeping owner and PI5 wake test.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-vm-sleep-wake-v1745.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
{
    printf '%s\n' '.text' '.globl vm_extent_move' '.globl fs_move_words'
    sed -n '/^vm_extent_move:$/,/^\/\*\*$/p' "$DAIMOS_REPO/system/kernel/proc/vm_pdp6.s" | sed '$d'
    printf '%s\n' '.data' '.globl kconst_6_6' 'kconst_6_6: .word 6,,6'
} > "$work/production.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
  --exec-mode step --start 1000 --step-limit 200000 --timeout 25 \
  --workdir "$work/run" --name vm_sleep_wake_v1745 \
  --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
  "$self/daimos-k01-vm-sleep-wake-v1745.s" "$work/production.s" > "$work/run.log" 2>&1 || {
    tail -35 "$work/run.log" >&2
    exit 1
  }
echo 'K01 v1745: sleeping VM owner and PI5 wake during move PASS'
