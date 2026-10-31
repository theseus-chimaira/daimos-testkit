#!/bin/sh
# PDP-6 native VM-less fatal cleanup: select executive continuation without swap.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-vmless-fatal-v879.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_sched_resched_select\n.globl proc_restore_kernel_tail\n'
    cat <<'EQU'
.equ PROC_WORDS,3
.equ PROC_STATE_LH_MASK,0700000
.equ PROC_STATE_SLEEP,0300000
.equ PROC_STATE_RUN,0200000
.equ PROC_NICE_LH_MASK,077
.equ PROC_CPU_LH_MASK,017
.equ PROC_SLEEP_LH_MASK,07
.equ PROC_NICE_BIAS,024
.equ PROC_TRANSITION_RH,0200000
.equ PROC_SCHED_READY_ONCE,01000
.equ PROC_FDCTL_OFFSET,024
.equ PROC_FILE_TABLE_OFFSET,026
.equ PROC_FATAL_CLOSE_BIT,4
.equ PROC_TIMER_CLOCK_MASK,0177777
.equ CTX_PC,020
.equ CTX_KSP,021
.equ CTX_M_USER_SP,022
.equ CTX_M_SYSCALL_SAVE,023
EQU
    sed -n '/^proc_sched_resched_select:$/,/^proc_adopt_children_pdp6:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
    sed -n '/^proc_restore_kernel_tail:$/,/^proc_restore_idle:$/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 300000 --timeout 20 \
    --workdir "$work/run" --name vmless-fatal-v879 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-vmless-fatal-v879.s" > "$work/log" 2>&1 || {
        tail -50 "$work/log" >&2
        exit 1
    }
echo 'v879: native VM-less fatal scheduler selection and APR-safe executive restore PASS'
