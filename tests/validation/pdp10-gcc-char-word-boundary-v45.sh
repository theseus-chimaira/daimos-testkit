#!/bin/sh
# Execute an optimized local QI array boundary read on a real PDP-6 target.
# Regression against GCC's late conversion of a word MEM_OFFSET to a byte.
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:?TMPDIR must be set}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/pdp10-gcc-char-word-boundary-v45-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
cc=${PDP10_GCC:-$PDP10_PREFIX/bin/pdp10-dec-none-gcc}
set -- "$cc"
if [ -n "${PDP10_GCC_B:-}" ]; then
        set -- "$@" "-B$PDP10_GCC_B"
fi

for optimize in 0 1 2 s; do
        "$@" -std=c99 "-O$optimize" \
            -march=pdp6 -mcpu=pdp6 -S \
            "$self/pdp10-gcc-char-word-boundary-v45.c" -o "$work/main.s"
        PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
            "$PDP10_PREFIX/bin/p10run" \
            --machine pdp6 --mode deposit --exec-mode step \
            --start 1000 --step-limit 200000 --timeout 15 \
            --workdir "$work/run-$optimize" \
            --name "pdp10-gcc-char-word-boundary-v45-O$optimize" \
            --expect __test_exit=0 \
            "$self/daimos-test-crt0-v1.s" \
            "$self/pdp10-gcc-char-word-boundary-helper-v45.s" \
            "$work/main.s" >/dev/null
        printf 'pdp10-gcc-char-word-boundary-v45: PASS -O%s\n' "$optimize"
done
