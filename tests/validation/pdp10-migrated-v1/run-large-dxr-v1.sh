#!/bin/sh
set -eu

: "${TMPDIR:?TMPDIR must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"

DAIMOS_REPO=${DAIMOS_REPO:-../DAIMOS}
DAIMOS_TOOLS_REPO=${DAIMOS_TOOLS_REPO:-../daimos-tools}
DAS=${DAS:-$PDP10_PREFIX/bin/das}
DLINK=${DLINK:-$PDP10_PREFIX/bin/dlink}
DXRCHECK=${DXRCHECK:-$PDP10_PREFIX/bin/dxrcheck}

work="$TMPDIR/daimos-large-dxr-20261006-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

cat > "$work/large.s" <<'EOF'
        .text
        .globl main
main:
        .word 0
        .block 040001
EOF

"$DAS" -F -C -O "$work/large.dobj" "$work/large.s"
"$DLINK" -b 020 -o "$work/large.dxr" "$work/large.dobj"
"$DXRCHECK" "$work/large.dxr" > "$work/dxrcheck.out"

# The synthetic image must genuinely cross the historical 036000-word limit.
image=$(sed -n 's/.*image=\([0-7][0-7]*\).*/\1/p' "$work/dxrcheck.out")
test -n "$image"
image_dec=$((0$image))
test "$image_dec" -gt $((036000))
test "$image_dec" -le $((0300000))

# Large ordinary images are a distinct limit from compact PURE-text swap
# metadata.  The latter intentionally remains 14 bits / 037777 words.
grep -q '^#define EXEC_DXR_MAX_IMAGE_WORDS[[:space:]]*0300000U' \
    "$DAIMOS_REPO/system/kernel/proc/exec.h"
grep -q '^[[:space:]]*\.equ[[:space:]]*EXEC_DXR_MAX_IMAGE_WORDS,0300000' \
    "$DAIMOS_REPO/system/kernel/proc/exec_load.s"
grep -q 'caile[[:space:]]*13,EXEC_DXR_MAX_IMAGE_WORDS' \
    "$DAIMOS_REPO/system/kernel/proc/exec_load.s"
! grep -q 'caile[[:space:]]*13,036000' \
    "$DAIMOS_REPO/system/kernel/proc/exec_load.s"
grep -q '^#define PROC_SWAP_TEXT_MASK[[:space:]]*037777UL' \
    "$DAIMOS_REPO/system/kernel/proc/proc_swap.h"
! grep -q 'EXEC_DXR_MAX_IMAGE_WORDS > PROC_SWAP_TEXT_MASK' \
    "$DAIMOS_REPO/system/kernel/proc/vm_pdp6_swap.c"

grep -q '^#define NL_MAX_IMAGE_WORDS[[:space:]]*0300000UL' \
    "$DAIMOS_TOOLS_REPO/native/dlink_native.c"
grep -q 'NL_MAX_RELMAP_WORDS.*NL_MAX_IMAGE_WORDS' \
    "$DAIMOS_TOOLS_REPO/native/dlink_native.c"

echo 'daimos-large-dxr: PASS'
