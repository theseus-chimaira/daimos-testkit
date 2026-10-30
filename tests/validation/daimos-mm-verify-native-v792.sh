#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/mm-verify-v792.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
{ printf '.text\n.equ MM_TYPE_PROCESS,1\n.equ MM_PIN_FIELD,03770000000\n.equ MM_PIN_ONE,010000000\n.globl mm_process_verify_pinned_v792\n'; sed -n '/^mm_find_base:$/,/^; int mm_is_pinned/p' "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'; sed -n '/^mm_process_verify_pinned_v792:$/,/^; Only a process extent pinned exactly once/p' "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d'; } > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step --start 1000 --step-limit 200000 --timeout 20 --workdir "$work/run" --name mm-verify-v792 --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" "$work/leaf.s" "$self/daimos-mm-verify-native-v792.s" > "$work/log" 2>&1 || { tail -30 "$work/log" >&2; exit 1; }
echo 'v792: native PDP-6 live MM descriptor validation PASS'
