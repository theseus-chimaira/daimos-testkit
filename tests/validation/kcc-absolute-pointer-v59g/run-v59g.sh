#!/bin/sh
# Static qualified absolute word pointers must be data, not .LINK code.
set -eu
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
KCC=${KCC:-$PDP10_PREFIX/bin/kcc}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/kcc-absolute-pointer-v59g.XXXXXX")
trap 'echo "v59g evidence: $work"' EXIT
for opt in -O -O0; do
    "$KCC" -Pgnu99 "$opt" -x=pdp6 -m=gas -S \
        "$here/test-native-v59g.c" -o "$work/probe$opt.s"
    if grep -i '\.LINK' "$work/probe$opt.s"; then
        echo "FAIL: static absolute word pointer emitted a constructor"
        exit 1
    fi
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/guest$opt" --name "ptr$opt" \
        --expect __test_exit=0 "$here/../daimos-test-crt0-v1.s" \
        "$work/probe$opt.s"
done
