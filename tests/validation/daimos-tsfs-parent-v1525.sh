#!/bin/sh
# Source-linked native TSFS parent/parent-name, v1525. Test both safe
# positive vnode outcomes and negative physical file-record responses.
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO required}"
: "${PDP10_PREFIX:?PDP10_PREFIX required}"
: "${TMPDIR:=${HOME}/tmp}"
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-tsfs-parent-v1525.XXXXXX")
if [ "${V1525_KEEP_PARENT_TEST:-0}" != 1 ]; then
        trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo, work = (Path(p) for p in sys.argv[1:])
src = (repo / 'system/kernel/fs/tsfs_runtime.s').read_text()
first = src.index('tsfs_parent_common:\n')
last = src.index('; int tsfs_stat(', first)
body = src[first:last]
vfs = (repo / 'system/kernel/fs/vfs.s').read_text()
first = vfs.index('vfs_name_from_words:\n')
last = vfs.index('; int vfs_name_is6(', first)
copy_name = vfs[first:last]
first = vfs.index('vfs_sixbit_name_chars:\n')
last = vfs.index('; MRES-backed VFS leaf operations.', first)
name_length = vfs[first:last]
source = '.text\n' + body + '\n' + copy_name + '\n' + name_length
for needle in ('jumpl   1,tsfs_parent_pop',
               'jumpl   1,tsfs_parent_name_pop',
               'pushj   17,tsfs_parent_common'):
    assert needle in body
(work / 'tsfs-source-v1525.s').write_text(source)
for name, old, new in (
    ('parent-nonzero-bug', 'jumpl   1,tsfs_parent_pop',
     'jumpn   1,tsfs_parent_pop'),
    ('parent-name-nonzero-bug', 'jumpl   1,tsfs_parent_name_pop',
     'jumpn   1,tsfs_parent_name_pop'),
):
    assert body.count(old) == 1
    (work / ('mutant-' + name + '-v1525.s')).write_text(
        source.replace(old, new, 1))
PY

run_case()
{
        name=$1
        asm=$2
        "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
            --exec-mode step --start 1000 --step-limit 220000 \
            --timeout 20 \
            --workdir "$work/run-$name" --name "tsfs-parent-$name-v1525" \
            --expect __test_exit=0 \
            "$self/daimos-test-crt0-v1.s" \
            "$self/daimos-tsfs-parent-v1525.s" "$asm" \
            > "$work/$name.log" 2>&1
}

if ! run_case baseline "$work/tsfs-source-v1525.s"; then
        tail -65 "$work/baseline.log" >&2
        exit 1
fi
echo 'PASS v1525: native TSFS parent and parent_name return success and real name'
for name in parent-nonzero-bug parent-name-nonzero-bug; do
        if run_case "$name" "$work/mutant-$name-v1525.s"; then
                echo "FAIL v1525: accepted unsafe $name" >&2
                exit 1
        fi
        if ! grep -q '^FAIL: __test_exit:' "$work/$name.log"; then
                tail -35 "$work/$name.log" >&2
                echo "FAIL v1525: mutation did not execute assertion: $name" >&2
                exit 1
        fi
        echo "PASS v1525: rejected $name source mutation"
done
