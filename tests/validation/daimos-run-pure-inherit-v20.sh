#!/bin/sh
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-run-pure-inherit-v20.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
source="$DAIMOS_REPO/system/kernel/proc/proc_run.s"
{
    printf '%s\n' '.text' '.globl proc_run_copy_cred' \
        '.equ PROC_CRED_OFFSET,066' 'proc_run_copy_cred:'
    sed -n '/^        move    4,040(7)/,/^proc_run_pure_ext_ready:/p' "$source"
    printf '%s\n' 'popj 17,'
} > "$work/inherit.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 100000 --timeout 15 \
    --workdir "$work/run" --name daimos-run-pure-inherit-v20 \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-run-pure-inherit-v20.s" "$work/inherit.s" >/dev/null
echo 'run-pure-inherit-v20: PASS (RUN retains credentials but not parental PURE backing bit)'
