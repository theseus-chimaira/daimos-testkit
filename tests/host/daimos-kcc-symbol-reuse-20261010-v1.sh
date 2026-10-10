#!/bin/sh
# Reused symbol slots must not retain graph edges from a former object.
set -eu
: "${KCC_REPO:?}" "${TMPDIR:?}"
w=$(mktemp -d "$TMPDIR/kcc-symbol-reuse-20261010-v1.XXXXXX")
trap 'rm -rf "$w"' EXIT HUP INT TERM
cat > "$w/test.c" <<'C99'
#include "ccsym.c"
#include <stdio.h>
#include <stdlib.h>
void efatal(char *fmt, ...) { (void)fmt; abort(); }
int main(void)
{
    static SYMBOL recycled, anchor;
    SYMBOL *tail = &anchor;
    SYMBOL *s;
    memset(&recycled, 0xa5, sizeof(recycled));
    recycled.Snext = NULL;
    symflist = &recycled;
    anchor.Snext = NULL;
    s = getsym(&tail);
    if (s != &recycled || symflist != NULL || tail != s ||
        s->Sprev != &anchor || anchor.Snext != s ||
        s->Ssmnext != NULL || s->Stype != NULL || s->Srefs != 0)
        return 1;
    puts("PASS: freelist symbol reused without stale graph edges");
    return 0;
}
C99
"${HOST_CC:-cc}" -std=c99 -O2 -ffunction-sections -fdata-sections \
    -I"$KCC_REPO" "$w/test.c" -Wl,--gc-sections -o "$w/test"
"$w/test"
