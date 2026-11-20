#!/bin/sh
# Native PDP-6 source-linked grow: preserve swap request pointer registers.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-k01-grow-registers-v1684.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
src="$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s"
{
    printf '%s\n' '.text' '.equ MM_TYPE_PROCESS,1' \
        '.equ MM_PIN_FIELD,03770000000' '.equ MM_PIN_ONE,010000000' \
        '.globl mm_process_grow_pinned'
    sed -n '/^mm_process_grow_pinned:$/,/^; AC1=base, AC2=+1\/\-1/p' "$src" | sed '$d'
} > "$work/production.s"
run()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 200000 \
        --timeout 25 --workdir "$work/run-$name" \
        --name "daimos-k01-grow-registers-v1684-$name" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" "$source" \
        "$self/daimos-k01-grow-registers-v1684.s" \
        > "$work/$name.log" 2>&1
}
run production "$work/production.s" || {
    tail -25 "$work/production.log" >&2
    exit 1
}
# Remove the preservation pair; the actual growth path must then fail.
sed '/^        push    17,010$/d; /^        push    17,011$/d; /^        pop     17,011$/d; /^        pop     17,010$/d' \
    "$work/production.s" > "$work/unsafe.s"
if run unsafe "$work/unsafe.s"; then
    echo 'K01 v1684: clobbered swap request registers unexpectedly passed' >&2
    exit 1
fi
echo 'K01 v1684: native PDP-6 growth retains AC10/AC11 and unsafe mutant rejected PASS'
