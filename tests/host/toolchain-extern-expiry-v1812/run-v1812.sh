#!/bin/sh
# Source-linked host DLINK/P10RUN regressions. All fixtures belong to testkit.
set -eu
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
: "${TOOL_SRC_DIR:?set TOOL_SRC_DIR to a DAIMOS tools/host or pdp10-tools checkout}"
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/toolchain-extern-expiry-v1812.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
cc=${HOST_CC:-cc}
das="$PDP10_PREFIX/bin/das"
darc="$PDP10_PREFIX/bin/darc"

# Compile the selected source, not installed binaries that might be stale.
"$cc" -std=c89 -O2 -Wall -Wextra -Werror \
    -o "$work/dlink-v1812" "$TOOL_SRC_DIR/dlink.c" "$TOOL_SRC_DIR/dobj.c"
{
    printf '#define main p10run_original_main_v1812\n'
    printf '#include "%s/p10run.c"\n' "$TOOL_SRC_DIR"
    printf '#undef main\n'
    cat "$here/runner-evaluate-v1812.inc"
} >"$work/p10run-evaluate-v1812.c"
"$cc" -std=c89 -O2 -Wall -Wextra -Werror \
    -o "$work/p10run-evaluate-v1812" "$work/p10run-evaluate-v1812.c"

for name in main left needed optional unused; do
    "$das" -C -F -O "$work/$name.dobj" "$here/$name-v1812.s"
done

# Genuine DOBJ1 symbol metadata: OPTIONAL must remain a declaration
# without relocation; NEEDED must have a one-based symbol relocation.
"$PDP10_PREFIX/bin/pdp10-objdump" "$work/main.dobj" >"$work/main.dump"
grep -q 'UNDEF .* OPTIONAL' "$work/main.dump"
grep -q 'UNDEF .* NEEDED' "$work/main.dump"
grep -q 'symbol=NEEDED' "$work/main.dump"
if grep -q 'symbol=OPTIONAL' "$work/main.dump"; then
    echo 'FAIL v1812: assembler unexpectedly referenced OPTIONAL' >&2
    exit 1
fi
"$PDP10_PREFIX/bin/pdp10-objdump" "$work/left.dobj" >"$work/left.dump"
grep -q 'type=4 symbol=NEEDED' "$work/left.dump"

# An unused EXTERN with no provider must not block linking.
"$work/dlink-v1812" -o "$work/unused.dxr" "$work/unused.dobj"
echo 'PASS v1812: undefined but unreferenced EXTERN accepted'

# An actual undefined relocation must still fail without its provider.
if "$work/dlink-v1812" -o "$work/missing.dxr" "$work/main.dobj" \
    >"$work/missing.log" 2>&1; then
    echo 'FAIL v1812: referenced NEEDED accepted without provider' >&2
    exit 1
fi
grep -q 'undefined symbol: NEEDED' "$work/missing.log"
echo 'PASS v1812: real unresolved relocation rejected'

# The archive must extract NEEDED, not the unused OPTIONAL member.
"$darc" -o "$work/providers.darc" \
    "$work/optional.dobj" "$work/needed.dobj"
"$work/dlink-v1812" -o "$work/direct.dxr" \
    "$work/main.dobj" "$work/needed.dobj"
"$work/dlink-v1812" -o "$work/archive.dxr" \
    "$work/main.dobj" "$work/providers.darc"
cmp "$work/direct.dxr" "$work/archive.dxr"
echo 'PASS v1812: only required archive member extracted'

# Left-half symbol relocations must use precisely the same provider rule.
"$work/dlink-v1812" -o "$work/left-direct.dxr" \
    "$work/left.dobj" "$work/needed.dobj"
"$work/dlink-v1812" -o "$work/left-archive.dxr" \
    "$work/left.dobj" "$work/providers.darc"
cmp "$work/left-direct.dxr" "$work/left-archive.dxr"
echo 'PASS v1812: left-half symbol relocation extracts only its provider'

"$work/p10run-evaluate-v1812"
echo 'PASS v1812: source-linked host toolchain regression matrix'
