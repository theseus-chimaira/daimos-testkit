#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-stack-watermark-v1239.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
source_file="$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"

# This executes the actual conditionalized production watermark leaves.
# Each constant must be exactly the value checked by the native fixture.
grep -q '^        .equ    KERNEL_IDLE_STACK_WORDS,0400$' "$source_file"
grep -q '^        .equ    PROC_KSTACK_WORDS,0315$' "$source_file"
grep -q '^#define KERNEL_IDLE_STACK_WORDS   00400UL$' \
    "$DAIMOS_REPO/system/kernel/boot/kinit.h"
{
    printf '.text\n.equ PROC_USTACK_BASE,070\n.equ PROC_KSTACK_WORDS,0315\n.equ KERNEL_IDLE_STACK_WORDS,0400\n.globl proc_stack_watermark_scan\n.globl kernel_idle_stack_watermark_scan\n'
    sed -n '/^proc_stack_watermark_scan:$/,/^\.endif$/p' "$source_file" | sed '$d'
} > "$work/stack-leaves.s"

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 20000 --timeout 20 \
    --workdir "$work/run" --name daimos-stack-watermark-v1239 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/stack-leaves.s" \
    "$self/daimos-stack-watermark-bounds-v1239.s" > "$work/result.log" 2>&1 || {
        tail -45 "$work/result.log" >&2
        exit 1
    }

# Both historical one-past comparisons must fail in the guest, not merely
# trip a textual source check. Each mutation retains valid PDP-6 assembly.
sed 's/caige  3,KERNEL_IDLE_STACK_WORDS/caig   3,KERNEL_IDLE_STACK_WORDS/' \
    "$work/stack-leaves.s" > "$work/idle-mutant.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 20000 --timeout 20 \
    --workdir "$work/idle-mutant" --name daimos-idle-overread-v1239 \
    --expect __test_exit=1 \
    "$self/daimos-test-crt0-v1.s" "$work/idle-mutant.s" \
    "$self/daimos-stack-watermark-bounds-v1239.s" \
    > "$work/idle-mutant.log" 2>&1 || {
        tail -35 "$work/idle-mutant.log" >&2
        exit 1
    }
sed 's/caige  3,PROC_KSTACK_WORDS/caig   3,PROC_KSTACK_WORDS/' \
    "$work/stack-leaves.s" > "$work/private-mutant.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 20000 --timeout 20 \
    --workdir "$work/private-mutant" --name daimos-private-overread-v1239 \
    --expect __test_exit=3 \
    "$self/daimos-test-crt0-v1.s" "$work/private-mutant.s" \
    "$self/daimos-stack-watermark-bounds-v1239.s" \
    > "$work/private-mutant.log" 2>&1 || {
        tail -35 "$work/private-mutant.log" >&2
        exit 1
    }
echo 'v1239: idle/private watermark exact bounds and two native mutants PASS'
