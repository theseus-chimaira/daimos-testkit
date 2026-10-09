#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:?TMPDIR must be set}"

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work="$TMPDIR/daimos-kcc-pointer-scan-pdp6-20261009-v1-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM

cat > "$work/start.s" <<'ASM'
        .text
        .globl _start
_start:
        move    17,[0777700,,stack-1]
        pushj   17,pointer_scan_regression
        movem   1,pointer_scan_regression_result
        halt    .
        .bss
        .globl pointer_scan_regression_result
pointer_scan_regression_result: .block 1
stack:   .block 0100
ASM

"${KCC_CC:-$PDP10_PREFIX/bin/kcc}" -Pgnu99 -O -x=pdp6 -m=gas \
        -S "$here/test.c" -o "$work/test.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --timeout 12 --workdir "$work/run" \
        --name daimos-kcc-pointer-scan-pdp6-20261009-v1 \
        --expect pointer_scan_regression_result=0 --report "$work/report.txt" \
        "$work/start.s" "$work/test.s"

echo 'daimos-kcc-pointer-scan-pdp6-20261009-v1: PASS'
