#!/bin/sh
# Source-linked VFS nonroot failed sync -> media return -> clean unmount.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-nonroot-unmount-retry-v1514.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

root, out = (Path(p) for p in sys.argv[1:])
source = (root/'system/kernel/fs/vfs.s').read_text()
first = source.index('vfs_unmount:\n')
last = source.index('        .data\n; KINIT publishes both bases', first)
segment = source[first:last]
for text in ('pushj   17,vfs_sync\n        jumpn   1,vfs_unmount_fail',
             'pushj   17,fs_provider_reg_call\n        jumpn   1,vfs_unmount_fail',
             'pushj   17,file_unlock_mount',
             'pushj   17,vfs_mount_retire_slot',
             'vfs_unmount_fail:\n        sub     17,kconst_2_2'):
    if segment.count(text) != 1:
        raise AssertionError('v1514 VFS ordering source drift: '+text)
head = '.text\n.globl vfs_unmount\n'
original = head + segment
(out/'vfs-unmount-v1514.s').write_text(original)
for name, old, new in (
        ('skip-sync-result',
         'pushj   17,vfs_sync\n        jumpn   1,vfs_unmount_fail',
         'pushj   17,vfs_sync\n        jrst    vfs_unmount_after_prepare'),
        ('skip-retirement',
         'pushj   17,vfs_mount_retire_slot',
         'pushj   17,kret_zero'),
        ('skip-unlock',
         'pushj   17,file_unlock_mount',
         'pushj   17,kret_zero')):
    if segment.count(old) != 1:
        raise AssertionError('v1514 mutation anchor ambiguous: '+name)
    (out/('vfs-mutant-'+name+'-v1514.s')).write_text(
        head + segment.replace(old,new,1))
PY

run_case() {
    tag=$1
    input=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 100000 --timeout 15 \
        --workdir "$work/run-$tag" --name "nonroot-$tag-v1514" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-nonroot-unmount-retry-v1514.s" \
        "$input" > "$work/$tag.log" 2>&1
}

run_case live "$work/vfs-unmount-v1514.s" || {
    tail -55 "$work/live.log" >&2
    exit 1
}
echo 'PASS v1514: missing nonroot media retains mount; return permits unmount'
for name in skip-sync-result skip-retirement skip-unlock; do
    if run_case "$name" "$work/vfs-mutant-$name-v1514.s"; then
        echo "FAIL v1514: unsafe $name accepted" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$name.log" || {
        echo "FAIL v1514: $name did not reach native failure oracle" >&2
        tail -35 "$work/$name.log" >&2
        exit 1
    }
    echo "PASS v1514: rejected $name ordering mutation"
done
