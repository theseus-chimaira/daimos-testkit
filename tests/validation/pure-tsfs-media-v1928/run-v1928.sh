#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-tsfs-media-v1928.XXXXXX")
trap 'echo "v1928 native evidence: $work"' EXIT
python3 "$here/prepare-v1928.py" "$DAIMOS_REPO" "$work"
for variant in base unsafe-set-id unsafe-generation unsafe-directory unsafe-copy-conflict unsafe-suspect unsafe-cache unsafe-scratch; do
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go --start 1000 --timeout 30 --workdir "$work/$variant" --name "pure-tsfs-media-$variant-v1928" --expect __test_exit=0 "$kit/tests/validation/daimos-test-crt0-v1.s" "$here/test-native-v1928.s" "$work/cases.s" "$work/$variant.s" > "$work/$variant.log" 2>&1; then
        [ "$variant" = base ] || { echo "FAIL: $variant accepted"; exit 1; }
        cat "$work/$variant.log"
    else
        [ "$variant" != base ] && grep -F 'FAIL: __test_exit' "$work/$variant.log" || { cat "$work/$variant.log"; exit 1; }
        echo "PASS: $variant rejected"
    fi
done
