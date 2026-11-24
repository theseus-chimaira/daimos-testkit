#!/bin/sh
# Run the declaration-call ABI regression with an installed or staged KCC.
set -eu
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
KCC=${KCC:-$PDP10_PREFIX/bin/kcc}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/kcc-init-abi-native-v1917.XXXXXX")
trap 'echo "v1917 native evidence: $work"' EXIT
for opt in O N; do
    for source in test callee; do
        "$KCC" -Pgnu99 "-$opt" -x=pdp6 -m=gas \
            -S "$here/$source-v1917.c" -o "$work/$source-$opt.s" \
            >"$work/$source-$opt.compile.log" 2>&1 || {
                cat "$work/$source-$opt.compile.log" >&2
                exit 1
            }
    done
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/guest-$opt" --name "kcc-init-abi-v1917-$opt" \
        --expect __test_exit=0 "$here/../daimos-test-crt0-v1.s" \
        "$work/test-$opt.s" "$work/callee-$opt.s"
done
