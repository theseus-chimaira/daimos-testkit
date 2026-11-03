#!/bin/sh
# Source-linked process EXIT transition: mark PREVM before PI6-masked idle.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-slot0-exit-premark-v1086.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
source_file="$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"
expect=0
if [ "${DAIMOS_V1086_NEGATIVE:-0}" = 1 ]; then
    git -C "$DAIMOS_REPO" show \
        6e0542b5:system/kernel/proc/proc_pdp6.s > "$work/old.s"
    source_file="$work/old.s"
    expect=1
fi
{
    printf '.text\n.equ PROC_STACK_WATERMARK,0\n'
    printf '.equ PROC_FINALIZE_OFFSET,067\n'
    printf '.equ PROC_FINALIZE_MARK_LH,0400000\n'
    printf '.equ PROC_FINALIZE_PREVM_LH,0100000\n'
    printf '.equ PROC_TRANSITION_RH,0200000\n'
    printf '.globl proc_exit_current\n'
    sed -n '/^proc_exit_current:$/,/^ \* @brief Finish an irreversible user fault/p' \
        "$source_file" | sed '$d' | sed '$d'
} > "$work/leaf.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 180000 --timeout 25 \
    --workdir "$work/run" --name slot0-exit-premark-v1086 \
    --expect __test_exit="$expect" \
    "$self/daimos-test-crt0-v1.s" "$work/leaf.s" \
    "$self/daimos-slot0-exit-premark-v1086.s" > "$work/log" 2>&1 || {
        tail -75 "$work/log" >&2
        exit 1
    }
if [ "$expect" = 0 ]; then
    echo 'v1086: private EXIT publishes PREVM marker before masked idle-stack handoff PASS'
else
    echo 'v1086: old EXIT lacks pre-HUP marker at PI6 handoff, negative FAIL expected'
fi
