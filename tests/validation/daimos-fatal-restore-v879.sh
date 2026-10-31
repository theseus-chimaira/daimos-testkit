#!/bin/sh
# Native PDP-6 sleeping executive context restore for VM-less fatal EXEC.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-fatal-restore-v879.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{
    printf '.text\n.globl proc_restore_kernel_tail\n'
    printf '.equ CTX_PC,020\n.equ CTX_KSP,021\n'
    printf '.equ CTX_M_USER_SP,022\n.equ CTX_M_SYSCALL_SAVE,023\n'
    printf '.equ PROC_FDCTL_OFFSET,024\n.equ PROC_FILE_TABLE_OFFSET,026\n'
    printf '.equ PROC_FATAL_CLOSE_BIT,4\n'
    sed -n '/^proc_restore_kernel_tail:$/,/^; Switch to the slot-0 executive idle loop/p' \
        "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 250000 --timeout 20 \
    --workdir "$work/run" --name fatal-restore-v879 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-fatal-restore-v879.s" > "$work/log" 2>&1 || {
        tail -45 "$work/log" >&2
        exit 1
    }
echo 'v879: native fatal EXEC VM_NONE scheduler resume and normal APR restoration PASS'
