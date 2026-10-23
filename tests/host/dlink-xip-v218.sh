#!/bin/sh
# Linker raw-XIP eligibility and binary format tests.  Keep host builds out
# of DAIMOS; exercise its current sources instead of a possibly stale install.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:?}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work="$TMPDIR/daimos-dlink-xip-v218-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM

${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/dlink-v218" "$DAIMOS_REPO/tools/host/dlink.c" \
    "$DAIMOS_REPO/tools/host/dobj.c"
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/xip-check-v218" "$here/dlink-xip-v218-check.c"

assemble()
{
        "$PDP10_PREFIX/bin/das" -C -O "$work/$1.dobj" "$work/$1.s"
}

cat > "$work/good.s" <<'EOF'
        .text
        .globl _start
_start: movei 1,0
        .word 040000000000
EOF
assemble good
"$work/dlink-v218" --pure --xip -b 020 -o "$work/good.xip" \
    -M "$work/good.map" "$work/good.dobj"
"$work/xip-check-v218" "$work/good.xip"
grep -Eq '^_start[[:space:]]+000020$' "$work/good.map"

reject()
{
        if "$work/dlink-v218" "$@" >"$work/rejected.log" 2>&1; then
                echo "FAIL: dlink unexpectedly accepted XIP case: $*" >&2
                exit 1
        fi
}
reject --xip -b 020 -o "$work/missing-pure.xip" "$work/good.dobj"
reject --pure --xip -b 0 -o "$work/wrong-origin.xip" "$work/good.dobj"
reject --pure --xip --rt-required -b 020 -o "$work/rt.xip" "$work/good.dobj"

cat > "$work/writable.s" <<'EOF'
        .text
_start: movei 2,01234
        movem 2,030
        .word 040000000000
EOF
assemble writable
reject --pure --xip -b 020 -o "$work/writable.xip" "$work/writable.dobj"

cat > "$work/other-uuo.s" <<'EOF'
        .text
_start: movei 1,0
        .word 041000000000
EOF
assemble other-uuo
reject --pure --xip -b 020 -o "$work/other-uuo.xip" "$work/other-uuo.dobj"

cat > "$work/data.s" <<'EOF'
        .text
_start: movei 1,0
        .word 040000000000
        .data
mutable: .word 01234
EOF
assemble data
reject --pure --xip -b 020 -o "$work/data.xip" "$work/data.dobj"

cat > "$work/bss.s" <<'EOF'
        .text
_start: movei 1,0
        .word 040000000000
        .bss
mutable: .block 1
EOF
assemble bss
reject --pure --xip -b 020 -o "$work/bss.xip" "$work/bss.dobj"

# The normal DXR/PURE path must still emit its distinct DXR header.
"$work/dlink-v218" --pure -b 020 -o "$work/ordinary.dxr" \
    "$work/good.dobj"
test -s "$work/ordinary.dxr"
echo 'PASS v218: XIP eligibility rejects bad origin, permissions, calls and data'
