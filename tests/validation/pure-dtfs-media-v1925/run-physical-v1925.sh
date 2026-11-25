#!/bin/sh
# Real DTFS provider identity leaf and parser with host-formatted physical records.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-dtfs-media-v1925.XXXXXX")
trap 'echo "v1925 physical leaf evidence: $work"' EXIT
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -o "$work/mkdtfs" "$DAIMOS_REPO/tools/host/mkdtfs.c"
"$work/mkdtfs" --durable-v1550 -o "$work/v2original.tap"
"$work/mkdtfs" --durable-v1550 -o "$work/v2replacement.tap"
"$work/mkdtfs" -o "$work/v1original.tap"
python3 "$here/prepare-physical-v1925.py" "$DAIMOS_REPO" "$kit" "$work"
for variant in baseline skip-proof skip-cache; do
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step --start 1000 --step-limit 550000 --timeout 30 --workdir "$work/$variant" --name "pure-dtfs-media-$variant-v1925" --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" "$work/fixture.s" "$work/records.s" "$DAIMOS_REPO/system/kernel/fs/dtfs_intent_validate_v1550.s" "$work/$variant.s" > "$work/$variant.log" 2>&1; then
        [ "$variant" = baseline ] || { echo "FAIL: unsafe $variant accepted"; exit 1; }
        cat "$work/$variant.log"
    else
        [ "$variant" != baseline ] && grep -F 'FAIL: __test_exit' "$work/$variant.log" || { cat "$work/$variant.log"; exit 1; }
        echo "PASS: unsafe $variant rejected"
    fi
done
