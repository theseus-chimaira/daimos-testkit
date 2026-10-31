#!/bin/sh
# Native PDP-6: execute compiled production C proc_exit_finish handoff.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-exit-deferred-v881.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
src="$DAIMOS_REPO/system/kernel"
# Compile with the production PDP-6 KCC configuration.
(
    cd "$src"
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -DPROC_FINISH_SLOT_PDP6_ASM=1 \
        -I. -Iboot -Icore -Idrivers -Ifs -Iipc -Imm -Imodules \
        -Iproc -Istorage -I"$PDP10_PREFIX/include" \
        -S proc/proc.c -o "$work/proc.s"
) > "$work/compiler.log" 2>&1
{
    printf '.text\n.globl proc_exit_finish\n'
    sed -n '/^proc_exit_finish:$/,/^proc_child_report:$/p' \
        "$work/proc.s" | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 250000 --timeout 20 \
    --workdir "$work/run" --name exit-deferred-v881 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-exit-deferred-v881.s" > "$work/log" 2>&1 || {
        printf 'v881 EXIT native diagnostic: %s\n' "$work" >&2
        tail -42 "$work/log" >&2
        exit 1
    }
echo 'v881: compiled C EXIT distinguishes deferred u-area owner from unrecoverable failure PASS'
