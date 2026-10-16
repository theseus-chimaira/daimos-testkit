#!/bin/sh
# Exercise the exact native credential leaves without KINIT/DSH/shell.
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-file-credential-bits-v18.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
proc="$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"
file="$DAIMOS_REPO/system/kernel/fs/file_runtime.s"

{
    printf '%s\n' '.text' '.globl proc_control_setcred' \
        '.globl proc_control_getuid' '.globl proc_control_getgid' \
        '.globl proc_control_umask' '.globl file_check_root' \
        '.equ PROC_CRED_OFFSET,066'
    sed -n '/^proc_control_getuid:/,/^proc_control_isatty:/p' "$proc" | sed '$d'
    sed -n '/^proc_control_umask:/,/^proc_control_tty_setfg:/p' "$proc" | sed '$d'
    sed -n '/^file_current_cred:/,/^; int file_open/p' "$file" | sed '$d'
    sed -n '/^file_check_root:/,/^; int file_check_owner/p' "$file" | sed '$d'
} > "$work/credential-leaves.s"

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 100000 --timeout 15 \
    --workdir "$work/run" --name daimos-file-credential-bits-v18 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-file-credential-bits-v18.s" \
    "$work/credential-leaves.s" >/dev/null
echo 'file-credential-bits-v18: PASS (compact UID/GID/UMASK, mount-extension word preserved)'
