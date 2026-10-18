#!/bin/sh
# Native PDP-6 queue test uses exact assembler leaves from CTY MRES.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-cty-packed-fifo-v23b.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
{
    printf '%s\n' '.text' '.globl cty_rx_put' '.globl cty_rx_get'
    sed -n '/^cty_rx_put:/,/^cty_putchar:/p' \
        "$DAIMOS_REPO/system/kernel/drivers/cty_io.s" | sed '$d'
} > "$work/cty-fifo.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 150000 --timeout 15 \
    --workdir "$work/run" --name daimos-cty-packed-fifo-v23b \
    --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-cty-packed-fifo-v23b.s" "$work/cty-fifo.s" >/dev/null
echo 'cty-packed-fifo-v23b: PASS (NUL, 10-byte saturation, ordering and reuse)'
