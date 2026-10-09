#!/bin/sh
# Ensure the temporary trap instrumentation assembles without CTY MRES linkage.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:=${HOME}/tmp}"
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-uuo-diag-20261009-v1.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
source="$DAIMOS_REPO/system/kernel/proc/mach_user_pdp6.s"
"$PDP10_PREFIX/bin/das" -F -C -O "$work/diag.dobj" "$source"
test -s "$work/diag.dobj"
grep -q 'movem 1,mach_invalid_uuo_word' "$source"
grep -q 'movem 1,mach_invalid_uuo_pc' "$source"
grep -q 'mach_invalid_oct36:' "$source"
if grep -Eq '^[[:space:]]*(pushj|jrst|.globl)[[:space:]]+.*cty_putchar' "$source"; then
    echo 'CTY module dependency unexpectedly introduced' >&2
    exit 1
fi
echo 'PASS: KCORE invalid UUO diagnostic assembles and captures trap/PC'
