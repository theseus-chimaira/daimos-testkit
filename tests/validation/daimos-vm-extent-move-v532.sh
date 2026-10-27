#!/bin/sh
# Real PDP-6 VM relocation routine and real FS move, minimal process fixture.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-vm-extent-v532.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
{
 printf '%s\n' '.text' '.globl vm_extent_move' '.globl fs_move_words'
 sed -n '/^vm_extent_move:/,/^\/\*\*/p' "$DAIMOS_REPO/system/kernel/proc/vm_pdp6.s" | sed '$d'
 sed -n '/^fs_copy_words:/,/^        \.globl  fs_zero_words/p' "$DAIMOS_REPO/system/kernel/fs/fs_mres.s" | sed '$d'
 printf '%s\n' '.data' '.globl kconst_6_6' 'kconst_6_6: .word 6,,6'
} > "$work/production.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
 --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" \
 --name daimos-vm-extent-move-v532 --expect __test_exit=0 \
 "$self/daimos-test-crt0-v1.s" "$self/daimos-vm-extent-move-v532.s" \
 "$work/production.s" >/dev/null
echo 'daimos-vm-extent-move-v532: PASS (real VM and FS transfer; no-uarea SIDL fixture)'
