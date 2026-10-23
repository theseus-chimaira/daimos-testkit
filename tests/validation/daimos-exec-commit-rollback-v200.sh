#!/bin/sh
# Production native EXEC staged transaction with mocked VM/loader boundaries.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-exec-commit-rollback-v200.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
source="$DAIMOS_REPO/system/kernel/proc/exec_lowmem_pdp6.s"
{
    printf '%s\n' '.text' '.globl exec_replace_current' \
        '.equ PROC_USER_MAP_BIT,2' \
        '.equ PROC_FDCTL_OFFSET,024' \
        '.equ PROC_CRED_OFFSET,066' \
        '.equ PROC_SWAP_BACKING_OFFSET,0406' \
        '.equ PROC_BRK_OFFSET,0407' \
        '.equ EXEC_LOAD_RT_REQUIRED,1' \
        '.equ EXEC_LOAD_NOMEM,-2'
    sed -n '/^        \.equ    EXEC_R_SAVE_FIRST/,/^        \.equ    EXEC_R_FRAME/p' "$source"
    sed -n '/^exec_replace_current:/,/^        ; Frame offsets relative to the fully advanced AC17/p' \
        "$source" | sed '$d'
    sed -n '/^sixbit_record_words:/,/^\/\*\*/p' \
        "$DAIMOS_REPO/system/kernel/proc/exec_load.s" | sed '$d'
} > "$work/exec-leaves.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 300000 --timeout 30 \
    --workdir "$work/run" --name daimos-exec-commit-rollback-v200 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-exec-commit-rollback-v200.s" "$work/exec-leaves.s" >/dev/null
echo 'exec-commit-rollback-v200: PASS (8 loader/startup/teardown/PURE/RT rollback and commit cases)'
