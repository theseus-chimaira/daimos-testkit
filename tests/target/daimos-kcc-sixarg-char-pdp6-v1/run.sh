#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:?TMPDIR must be set}"

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work="$TMPDIR/daimos-kcc-sixarg-char-pdp6-v1-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM

kcc="$PDP10_PREFIX/bin/kcc"
das="$PDP10_PREFIX/bin/das"
p10run="$PDP10_PREFIX/bin/p10run"

cat >"$work/start.s" <<'EOF_ASM'
        .text
        .globl  _start
_start:
        move    17,[0777700,,stack-1]
        pushj   17,kcc_sixarg_char_test
        movem   1,kcc_sixarg_char_result
        halt    .
        .bss
        .globl  kcc_sixarg_char_result
kcc_sixarg_char_result: .block 1
stack:  .block 0100
EOF_ASM

cp "$here/test.c" "$work/test.c"
(cd "$work" && "$kcc" -Pgnu99 -O -x=pdp6 -m=gas -S test.c -o test.s)
"$das" -F -C -O "$work/test.dobj" "$work/test.s"

PDP10_PREFIX="$PDP10_PREFIX" "$p10run" \
    --machine pdp6 --mode deposit --exec-mode go --timeout 10 \
    --workdir "$work/run" --name daimos-kcc-sixarg-char-pdp6-v1 \
    --expect kcc_sixarg_char_result=0 \
    --report "$work/report.txt" "$work/start.s" "$work/test.s"

printf '%s\n' 'daimos-kcc-sixarg-char-pdp6-v1: PASS'
