#!/bin/sh
# Actual PDP-6 Type-551 first-block search, write and read regression.
# Exercise RBN0145, the first native DTFS data block, independently of VFS.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtc-next-block-v1529.XXXXXX")
if [ "${DTC_NEXT_BLOCK_KEEP_V1529:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$self" "$work" <<'PY'
from pathlib import Path
import sys

source_root, output_root = (Path(s) for s in sys.argv[1:])
base = (source_root / 'daimos-dtc-stream-online-v1.s').read_text()
assert base.count('        setz 1,') == 3
assert base.count('move 2,[000200,,000200]') == 2
assert base.count('        movei 3,0400\ncompare_loop:') == 1
# Keep the production DTC runtime and PI/DCT dispatch intact.
# Only alter the fixture's physical unit, RBN and transfer length.
base = base.replace('        setz 1,', '        movei 1,3', 2)
base = base.replace('        movei 3,0400\ncompare_loop:',
                    '        movei 3,0200\ncompare_loop:', 1)
for block in ('000145',):
    path = output_root / ('block-' + block)
    path.mkdir()
    code = base.replace('move 2,[000200,,000200]',
                        'move 2,[000000,,' + block + ']')
    (path / 'source-v1524.s').write_text(code)
    (path / 'dtc.ini').write_text(
        'set DCT enabled\n'
        'set DTC enabled\n'
        'set DTC3 enabled\n'
        'set DTC DCT=4\n'
        'attach -q DTC3 ' + str(path / 'dtc3.tap') + '\n')
PY

test_case()
{
    block=$1
    simulator=$2
    label=$3
    dir="$work/block-$block"
    SIMH_PDP6="$simulator" "$PDP10_PREFIX/bin/p10run" \
        --machine pdp6 --mode deposit --exec-mode go \
        --start 1000 --timeout 50 \
        --workdir "$dir/run-$label" \
        --name "dtc-first-mark-$block-$label-v1524" \
        --ini "$dir/dtc.ini" --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$dir/source-v1524.s" \
        "$DAIMOS_REPO/system/kernel/drivers/tape_io.s" \
        "$DAIMOS_REPO/system/kernel/storage/storage_router.s" \
        "$self/daimos-dtc-stream-online-stubs-v1.s" \
        > "$dir/$label.log" 2>&1
}

simulator=${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}
for block in 000145; do
    dir="$work/block-$block"
    "$PDP10_PREFIX/bin/mkdtfs" -o "$dir/dtc3.tap" >/dev/null
    if ! test_case "$block" "$simulator" corrected; then
        tail -40 "$dir/corrected.log" >&2
        echo "FAIL v1529: real DTC3 block $block" >&2
        exit 1
    fi
    echo "PASS v1529: real DTC3 search/write/read block $block"
done
