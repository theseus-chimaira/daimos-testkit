#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-pure-backing-write-v962.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
 printf '.text\n.globl proc_swap_backing_busy\n'
 printf '.equ PROC_SWAP_BACKING_OFFSET,0406\n.equ PROC_SWAP_MOUNT_SHIFT,022\n.equ PROC_SWAP_TEXT_SHIFT,026\n.equ PROC_SWAP_TEXT_MASK,037777\n'
 sed -n '/^proc_swap_backing_busy:$/,/^\/\* Return nonzero while/p' "$DAIMOS_REPO/system/kernel/proc/proc_pure_backing_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
 --exec-mode step --start 1000 --step-limit 120000 --timeout 20 \
 --workdir "$work/run" --name pure-backing-write-v962 --expect __test_exit=0 \
 "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
 "$self/daimos-pure-backing-write-v962.s" > "$work/log" 2>&1 || {
 tail -45 "$work/log" >&2
 exit 1
 }
echo 'v962: resident and swapped PURE write guard PASS'
