#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:?TMPDIR must be set}"

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-gcc-stack-char-v153-$$"
mkdir -p "$work"
if [ "${DAIMOS_TEST_KEEP:-0}" != 1 ]; then
        trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

cat > "$work/start.s" <<'ASM'
        .text
        .globl _start
_start:
        ; The 256-character C stack frame exceeds the usual 64-word test
        ; pushdown limit. Keep the limit consistent with 01000 words below.
        move 17,[0777000,,stack-1]
        pushj 17,stack_char_test
        movem 1,stack_char_result
        halt .

        .globl fill_local
fill_local:
        ; The incoming C char * is a packed PDP-10 byte pointer.
        ; Use only its already-adjusted word address, not C byte stores.
        hrrz 3,1
        move 4,[043043040100]       ; ## @
        movem 4,0(3)
        move 4,[077117120105]       ; ?OPE
        movem 4,1(3)
        move 4,[122101116104]       ; RAND
        movem 4,2(3)
        setz 1,
        popj 17,

        .bss
        .globl stack_char_result
stack_char_result: .block 1
stack: .block 01000
ASM

cc=${PDP10_GCC:-$PDP10_PREFIX/bin/pdp10-dec-none-gcc}
p10run=${P10RUN:-$PDP10_PREFIX/bin/p10run}
for opt in 0 1 2 s; do
        if [ -n "${PDP10_GCC_B:-}" ]; then
                "$cc" -B"$PDP10_GCC_B" -std=c99 -O"$opt" \
                    -march=pdp6 -mcpu=pdp6 -S "$here/test.c" \
                    -o "$work/test.s"
        else
                "$cc" -std=c99 -O"$opt" -march=pdp6 -mcpu=pdp6 \
                    -S "$here/test.c" -o "$work/test.s"
        fi
        "$p10run" --machine pdp6 --mode deposit \
            --exec-mode go --timeout 25 \
            --workdir "$work/run-$opt" --name "gcc-stack-char-v153-O$opt" \
            --expect stack_char_result=1 --report "$work/report-$opt.txt" \
            "$work/start.s" "$work/test.s"
        echo "PASS: PDP-6 local packed char array -O$opt"
done
