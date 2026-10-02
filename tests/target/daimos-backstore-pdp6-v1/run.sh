#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work="$TMPDIR/daimos-testkit-backstore-pdp6-v1-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
p10run="$PDP10_PREFIX/bin/p10run"
kernel="$DAIMOS_REPO/system/kernel"
cat >"$work/start.s" <<'EOF_ASM'
        .text
        .globl  _start
_start:
        move    17,[0777700,,stack-1]
        pushj   17,daimos_backstore_pdp6_test
        movem   1,daimos_backstore_pdp6_result
        halt    .
        .bss
stack:  .block  0100
EOF_ASM
"$cc" -std=c99 -Os -I"$kernel/core" -I"$kernel/storage" \
    -S "$here/test.c" -o "$work/test.s"
PDP10_PREFIX="$PDP10_PREFIX" "$p10run" \
    --machine pdp6 --mode deposit --exec-mode go --timeout 10 \
    --workdir "$work/run" --name daimos-backstore-pdp6-v1 \
    --expect daimos_backstore_pdp6_result=0 --report "$work/report.txt" \
    "$work/start.s" "$work/test.s" "$kernel/storage/backstore.s"
