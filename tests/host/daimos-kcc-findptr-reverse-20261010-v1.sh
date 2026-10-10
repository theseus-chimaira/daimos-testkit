#!/bin/sh
# Exercise the production KIR pointer lookup and verify stable IDs.
set -eu
: "${KCC_REPO:?}" "${TMPDIR:?}"
work=$(mktemp -d "$TMPDIR/daimos-kcc-findptr-reverse-20261010-v1.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
cat > "$work/check.c" <<'SOURCE'
#include "cckirwrite.c"
#include <stdio.h>
int main(void)
{
    enum { COUNT = 4096 };
    static unsigned objects[COUNT];
    static void *ptrs[COUNT];
    unsigned INT bounds[2];
    unsigned i;
    void *missing;
    for (i = 0; i < COUNT; ++i) ptrs[i] = &objects[i];
    bounds[0] = (unsigned INT)ptrs[0];
    bounds[1] = (unsigned INT)ptrs[COUNT - 1];
    if (findptr(ptrs, 0U, ptrs[0], bounds) != 0U) return 1;
    for (i = 0; i < COUNT; ++i)
        if (findptr(ptrs, COUNT, ptrs[i], bounds) != i + 1U) return 2;
    missing = (void *)((char *)&objects[COUNT / 2] + 1);
    if (findptr(ptrs, COUNT, missing, bounds) != 0U) return 3;
    if (findptr(ptrs, COUNT, (void *)0, bounds) != 0U) return 4;
    puts("PASS: production KIR pointer identity and discovery IDs");
    return 0;
}
SOURCE
"${HOST_CC:-cc}" -std=c99 -O2 -ffunction-sections -fdata-sections \
    -I"$KCC_REPO" "$work/check.c" -Wl,--gc-sections -o "$work/check"
"$work/check"
