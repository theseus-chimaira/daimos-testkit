#!/bin/sh
# Verify production KIR typed pointer lookup and stable one-based IDs.
set -eu
: "${KCC_REPO:?}" "${TMPDIR:?}"
work=$(mktemp -d "$TMPDIR/daimos-kcc-typed-pointer-reverse-20261011-v2.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
cat > "$work/check.c" <<'SOURCE'
#include "cckirwrite.c"
#include <stdio.h>

#define CHECK_LOOKUP(func, type) do { \
    static type objects[4096]; \
    static type *ptrs[4096]; \
    unsigned i; \
    for (i = 0; i < 4096U; ++i) ptrs[i] = &objects[i]; \
    if (func(ptrs, 0U, ptrs[0]) != 0U) return 1; \
    for (i = 0; i < 4096U; ++i) \
        if (func(ptrs, 4096U, ptrs[i]) != i + 1U) return 2; \
    if (func(ptrs, 4096U, (type *)0) != 0U) return 3; \
} while (0)

int main(void)
{
    CHECK_LOOKUP(findnode, NODE);
    CHECK_LOOKUP(findtype, TYPE);
    CHECK_LOOKUP(findsymbol, SYMBOL);
    puts("PASS: production KIR typed pointer identity and discovery IDs");
    return 0;
}
SOURCE
"${HOST_CC:-cc}" -std=c99 -O2 -ffunction-sections -fdata-sections \
    -I"$KCC_REPO" "$work/check.c" -Wl,--gc-sections -o "$work/check"
"$work/check"
