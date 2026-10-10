#!/bin/sh
# KGEN switch table data pseudo-ops must have zero accumulator effects.
set -eu
: "${KCC_REPO:?}" "${TMPDIR:?}"
w=$(mktemp -d "$TMPDIR/kcc-literal-pseudo-20261010-v1.XXXXXX")
trap 'rm -rf "$w"' EXIT HUP INT TERM
cat > "$w/check.c" <<'C99'
#include "cccreg.c"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
char popprc[256];
char popflg[256];
void int_error(char *fmt, ...) { (void)fmt; abort(); }
/* The regression enters the real creg(), but does not need a pcode chain. */
int dropsout(PCODE *p) { (void)p; return 0; }
PCODE *before(PCODE *p) { (void)p; return NULL; }
PCODE *after(PCODE *p) { (void)p; return NULL; }
void unskip(PCODE *p) { (void)p; }
int main(void)
{
    PCODE p;
    unsigned i;
    const int op[] = {P_NOP, P_CVALUE, P_IFIW};
    memset(&p, 0, sizeof(p));
    for (i = 0; i < sizeof(op)/sizeof(op[0]); ++i) {
        p.Pop = op[i];
        p.Ptype = (op[i] == P_IFIW) ? PTA_MINDEXED : PTA_RCONST;
        p.Preg = 4;
        p.Pindex = 5;
        if (rbincode(&p) != 0 || rinreg(&p,4) != 0) return 1;
        rvsset(&p);
        if (rvread != 0 || rvwrit != 0) return 2;
        if (creg(5, 4, &p, NULL, NULL) != 0) return 3;
    }
    puts("PASS: NOP, CVALUE and IFIW have no register effects or unsafe renaming");
    return 0;
}
C99
"${HOST_CC:-cc}" -std=c99 -O2 -ffunction-sections -fdata-sections \
    -I"$KCC_REPO" "$w/check.c" -Wl,--gc-sections -o "$w/check"
"$w/check"
