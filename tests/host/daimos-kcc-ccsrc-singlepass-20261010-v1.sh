#!/bin/sh
# Check that the C-SIX source reader still produces decoded source bytes.
set -eu
: "${KCC_REPO:?}" "${PDP10_PREFIX:?}" "${TMPDIR:?}"
work=$(mktemp -d "$TMPDIR/daimos-kcc-ccsrc-singlepass-20261010-v1.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
printf 'int main(void) { return 0; }\n' > "$work/input.c"
"$PDP10_PREFIX/bin/csix" -e "$work/input.c" "$work/input.s6"
cat > "$work/check.c" <<'C99'
#include <stdio.h>
#include <string.h>
#include "ccsrc.h"
int main(int argc, char **argv)
{
    FILE *f;
    CCSRC s;
    char out[256];
    int c;
    size_t i = 0;
    if (argc != 2 || (f = fopen(argv[1], "rb")) == NULL) return 1;
    if (ccsrc_init(&s, f) != 0 || s.mode != CCSRC_CSIX_S6REC) return 2;
    while ((c = ccsrc_getc(&s)) != EOF && i + 1 < sizeof(out))
        out[i++] = (char)c;
    out[i] = '\0';
    if (ccsrc_error(&s) || strcmp(out, "int main(void) { return 0; }\n")) return 3;
    return fclose(f) != 0;
}
C99
"${HOST_CC:-cc}" -std=c99 -Wall -Wextra -I"$KCC_REPO" \
    "$work/check.c" "$KCC_REPO/ccsrc.c" -o "$work/check"
"$work/check" "$work/input.s6"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -x=pdp6 -m=gas \
    -DHOST_DAIMOS=1 -DHOST_UNIX=0 -I"$KCC_REPO/self/include" \
    -S "$KCC_REPO/ccsrc.c" -o "$work/ccsrc.s" >/dev/null
"$PDP10_PREFIX/bin/das" -F -C -O "$work/ccsrc.dobj" "$work/ccsrc.s"
[ -s "$work/ccsrc.dobj" ]
echo 'PASS: C-SIX decode and native PDP-6 source reader compile'
