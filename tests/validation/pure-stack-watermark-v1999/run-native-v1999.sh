#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
w=$(mktemp -d "$TMPDIR/pure-stack-watermark-v1999.XXXXXX")
echo "evidence $w"
src="$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"
if [ "$#" -gt 0 ]; then src=$1; fi
{
    printf '.text\n.equ PROC_USTACK_BASE,070\n.equ PROC_KSTACK_WORDS,0315\n.equ KERNEL_IDLE_STACK_WORDS,0400\n.globl proc_stack_watermark_scan\n.globl kernel_idle_stack_watermark_scan\n'
    sed -n '/^proc_stack_watermark_scan:$/,/^\.endif$/p' "$src" | sed '$d'
} > "$w/leaves.s"
for cpu in pdp6 ka10; do
    "$PDP10_PREFIX/bin/p10run" --machine "$cpu" --mode deposit --exec-mode step --start 1000 --step-limit 40000 --timeout 40 --workdir "$w/$cpu" --name "stack-v1999-$cpu" --expect "__test_exit=${V1999_EXPECT:-0}" "$here/../daimos-test-crt0-v1.s" "$w/leaves.s" "$here/native-v1999.s" >"$w/$cpu.log" 2>&1 || { tail -50 "$w/$cpu.log"; exit 1; }
    echo "PASS $cpu expected ${V1999_EXPECT:-0}"
done
