#!/bin/sh
# Guard native KCPP raw C-SIX include decoding and PDP-6 compilation.
set -eu
: "${KCC_REPO:?}" "${PDP10_PREFIX:?}" "${TMPDIR:?}"
work=$(mktemp -d "$TMPDIR/daimos-kcc-s6rec-include-mode-20261010-v1.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
(
    cd "$KCC_REPO"
    "${HOST_KCC:-$PDP10_PREFIX/bin/kcc}" \
        -Pgnu99 -x=pdp6 -m=gas -DHOST_DAIMOS=1 -DHOST_UNIX=0 \
        -DKCC_PHASE_CPP=1 -Iself/include/ -Hself/include/ \
        -S ccpp.c -o "$work/ccpp.s"
)
"$PDP10_PREFIX/bin/das" -F -C -O "$work/ccpp.dobj" "$work/ccpp.s"
test -s "$work/ccpp.dobj"
# The source must keep ordinary hosts' original binary-open semantics.
grep -q 'define CPP_INCLUDE_MODE "r"' "$KCC_REPO/ccpp.c"
grep -q 'define CPP_INCLUDE_MODE "rb"' "$KCC_REPO/ccpp.c"
echo 'PASS: DAIMOS KCPP S6REC include mode compiles and assembles'
