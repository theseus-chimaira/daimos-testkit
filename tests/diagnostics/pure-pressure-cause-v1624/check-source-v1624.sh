#!/bin/sh
# Source-integrity and diagnostic-branch checks; no simulator needed.
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../.." && pwd)
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/pure-v1624-source.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
for children in 5 6; do
    for target in 016000 017000; do
        python3 "$here/prepare-v1624.py" \
            "$testkit/diagnostics/pure-brk-pressure-v1614/test-v1614.c" \
            "$work/variant.c" --children "$children" --target "$target"
        grep -q "#define P14_CHILDREN         ${children}U" "$work/variant.c"
        grep -q "#define P14_BRK_TARGET       ${target}UL" "$work/variant.c"
        grep -q "p14_fail('r');" "$work/variant.c"
        grep -q "p14_fail('s');" "$work/variant.c"
        if grep -q "p14_fail('c');" "$work/variant.c"; then
            echo 'FAIL v1624: ambiguous refusal is still present' >&2
            exit 1
        fi
    done
done
echo 'PASS v1624: four typed, source-authenticated pressure variants'
