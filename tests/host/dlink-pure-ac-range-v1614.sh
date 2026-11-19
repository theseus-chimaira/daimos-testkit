#!/bin/sh
# Source-authentic DAIMOS dlink PURE address analysis, v1614.
# A direct store to the accumulator file is not a TEXT write; a store
# into the relocated TEXT address range must still be refused.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/dlink-pure-ac-v1614.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

# A source-linked host linker test must not rely on the installed binary
# (which can predate the bug fix). Keep the compiler requirement C89.
${HOST_CC:-cc} -std=c89 -O2 -Wall -Wextra -Werror \
    -o "$work/dlink-v1614" "$DAIMOS_REPO/tools/host/dlink.c" \
    "$DAIMOS_REPO/tools/host/dobj.c"
das="$PDP10_PREFIX/bin/das"
check="$PDP10_PREFIX/bin/dxrcheck"

cat >"$work/ac.s" <<'EOF'
        .text
        .globl _start
_start:
        movei   1,7
        pop     17,10
        movem   1,10
        .rept   24
        setz    1,
        .endr
        halt    .
EOF
"$das" -C -F -O "$work/ac.dobj" "$work/ac.s"
"$work/dlink-v1614" --pure -b 020 \
    -o "$work/ac.dxr" "$work/ac.dobj"
"$check" -d "$work/ac.dxr" >"$work/ac.check"
grep -q 'purity=PURE' "$work/ac.check"
echo 'PASS v1614: unindexed POP/MOVEM into AC10 are not TEXT writes'

cat >"$work/direct.s" <<'EOF'
        .text
        .globl _start
_start:
        movei   1,7
        movem   1,020
        halt    .
EOF
"$das" -C -F -O "$work/direct.dobj" "$work/direct.s"
if "$work/dlink-v1614" --pure -b 020 \
    -o "$work/direct.dxr" "$work/direct.dobj" \
    >"$work/direct.log" 2>&1; then
    echo 'FAIL v1614: direct write to relocated TEXT accepted' >&2
    exit 1
fi
grep -q 'contradicted by definite TEXT write' "$work/direct.log"
echo 'PASS v1614: direct writing EA=020 rejected at link base 020'

cat >"$work/reloc.s" <<'EOF'
        .text
        .globl _start
_start:
        movei   1,7
        movem   1,target
target:
        halt    .
EOF
"$das" -C -F -O "$work/reloc.dobj" "$work/reloc.s"
if "$work/dlink-v1614" --pure -b 0400 \
    -o "$work/reloc.dxr" "$work/reloc.dobj" \
    >"$work/reloc.log" 2>&1; then
    echo 'FAIL v1614: relocated direct TEXT write accepted' >&2
    exit 1
fi
grep -q 'contradicted by definite TEXT write' "$work/reloc.log"
echo 'PASS v1614: relocated target at 0402 rejected for base 0400'

# Base zero is used by non-user tools. AC0..AC17 must remain an
# accumulator bank even when the source image itself starts at zero.
"$work/dlink-v1614" --pure -b 0 -o "$work/ac-zero.dxr" \
    "$work/ac.dobj"
"$check" -d "$work/ac-zero.dxr" >"$work/ac-zero.check"
grep -q 'purity=PURE' "$work/ac-zero.check"
echo 'PASS v1614: AC0..AC17 writes do not reject base-zero PURE'

echo 'PASS v1614: dlink PURE base-aware/AC-safe TEXT-write analysis'
