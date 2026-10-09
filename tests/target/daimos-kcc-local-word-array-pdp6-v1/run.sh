#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:?TMPDIR must be set}"

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work="$TMPDIR/daimos-kcc-local-word-array-pdp6-v1-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM

kcc="$PDP10_PREFIX/bin/kcc"
p10run="$PDP10_PREFIX/bin/p10run"

cat >"$work/start.s" <<'EOF_ASM'
        .text
        .globl  _start
_start:
        move    17,[0777700,,stack-1]
        pushj   17,kcc_local_word_array_test
        movem   1,kcc_word_array_result
        halt    .
        .bss
        .globl  kcc_word_array_result
kcc_word_array_result: .block 1
stack:  .block 0100
EOF_ASM

"$kcc" -Pgnu99 -O -x=pdp6 -m=gas -S "$here/test.c" -o "$work/test.s"
PDP10_PREFIX="$PDP10_PREFIX" "$p10run" \
    --machine pdp6 --mode deposit --exec-mode go --timeout 10 \
    --workdir "$work/run" --name daimos-kcc-local-word-array-pdp6-v1 \
    --expect kcc_word_array_result=0 --report "$work/report.txt" \
    "$work/start.s" "$work/test.s"

printf '%s\n' 'daimos-kcc-local-word-array-pdp6-v1: PASS'
