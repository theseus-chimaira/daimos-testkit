#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
vector_dir="$here/../daimos-d6lz-pdp6-v1"
work="$TMPDIR/daimos-stage1-d6lz-pdp6-v1-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
p10run="$PDP10_PREFIX/bin/p10run"
kernel="$DAIMOS_REPO/system/kernel"
inc="$DAIMOS_REPO/system/stand/pdp6/common/decompressor.inc"
cat >"$work/start.s" <<EOF_ASM
        .text
        .globl  _start
_start:
        movei   1,d6lz_image_start
        hrl     1,1
        hrri    1,d6lz_fixed_base
        blt     1,d6lz_fixed_base+(d6lz_image_end-d6lz_image_start)-1
        move    17,[0777700,,stack-1]
        pushj   17,daimos_d6lz_pdp6_test
        movem   1,daimos_d6lz_pdp6_result
        halt    .


; Test-only compatibility wrapper.  The production PDP-10 kernel deliberately
; keeps only the resumable core resident; this wrapper proves the copied image
; at 000060 through the historical memory-decoder ABI used by test.c.
        .globl  d6lz36_decode
d6lz36_decode:
        push    17,10
        push    17,11
        push    17,12
        push    17,13
        push    17,14
        jumpe   2,d6lz_test_success
        jumpe   1,d6lz_test_error
        jumpe   3,d6lz_test_error
        move    12,1
        move    13,2
        move    14,1
        setz    11,
        pushj   17,d6lz_fixed_base
        jumpe   0,d6lz_test_success
d6lz_test_error:
        seto    1,
        jrst    d6lz_test_return
d6lz_test_success:
        setz    1,
d6lz_test_return:
        pop     17,14
        pop     17,13
        pop     17,12
        pop     17,11
        pop     17,10
        popj    17,

        .include "$inc"
        .bss
stack:  .block  0200
EOF_ASM
"$cc" -std=c99 -Os -I"$PDP10_PREFIX/include" -I"$kernel/core" -S "$vector_dir/test.c" -o "$work/test.s"
PDP10_PREFIX="$PDP10_PREFIX" "$p10run" \
    --machine pdp6 --mode deposit --exec-mode go --timeout 60 \
    --workdir "$work/run" --name daimos-stage1-d6lz-pdp6-v1 \
    --expect daimos_d6lz_pdp6_result=0 --report "$work/report.txt" \
    "$work/start.s" "$work/test.s" "$kernel/core/d6lz_pdp6.s"
