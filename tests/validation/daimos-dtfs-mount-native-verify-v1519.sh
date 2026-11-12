#!/bin/sh
# v1519 PDP-6 source-linked physical native-directory mount admission.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-mount-native-v1519.XXXXXX")
if [ "${V1519_KEEP_TEST:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo, work = (Path(x) for x in sys.argv[1:])
dtfs = (repo / 'system/kernel/fs/dtfs_runtime.s').read_text()
first = dtfs.index('dtfs_mount_unit:\n')
last = dtfs.index('dtfs_lookup:\n', first)
mount = dtfs[first:last]
restore_first = dtfs.index('dtfs_restore4:\n')
restore_last = dtfs.index('; Compact vnode predicates.', restore_first)
restore = dtfs[restore_first:restore_last]
cache = (repo / 'system/kernel/storage/bcache_pdp6.s').read_text()
cache_first = cache.index('bcache_invalidate_all:\n')
cache_last = cache.index('; void bcache_workspace_invalidate', cache_first)
invalidate = cache[cache_first:cache_last]

head = ('.text\n.set DTFS_ENABLE_TENEX,0\n'
        '.set DTFS_ENABLE_ITS,0\n.set DTFS_ENABLE_FOREIGN,0\n'
        '.globl dtfs_mount_unit\n.globl bcache_invalidate_all\n')
source = head + restore + mount + invalidate
for needle in ('pushj   17,dtfs_dtc_read_jump',
               'pushj   17,bcache_invalidate_all',
               'setzm   dtfs_cache_mount',
               'came    1,[0446446632021]',
               'caie    1,036',
               'came    1,[0167572]',
               'pushj   17,vfs_mount_prevalidated'):
    if needle not in mount:
        raise AssertionError('v1519 production mount gate drift: ' + needle)
(work / 'mount-source-v1519.s').write_text(source)

mutations = (
    ('skip-physical-verification',
     'movei   2,0144                  ; native directory block\n'
     '        movei   3,fs_block_workspace\n'
     '        pushj   17,dtfs_dtc_read_jump',
     'movei   2,0144                  ; native directory block\n'
     '        movei   3,fs_block_workspace\n'
     '        pushj   17,kret_zero'),
    ('skip-cache-invalidation',
     'pushj   17,bcache_invalidate_all', 'pushj   17,kret_zero'),
    ('wrong-magic-check',
     'came    1,[0446446632021]', 'camn    1,[0446446632021]'),
    ('skip-first-reserved',
     'move    1,fs_block_workspace\n        lsh     1,-037',
     'movei   1,036\n        lsh     1,0'),
    ('skip-directory-reserved',
     'move    1,fs_block_workspace+014\n        lsh     1,-025',
     'movei   1,036\n        lsh     1,0'),
    ('skip-native-sentinels',
     'move    1,fs_block_workspace+0122', 'move    1,[0167572]'))
for name, old, new in mutations:
    if mount.count(old) != 1:
        raise AssertionError('ambiguous mutation anchor: '+name)
    (work / ('mutant-' + name + '-v1519.s')).write_text(
        source.replace(old, new, 1))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 300000 --timeout 20 \
        --workdir "$work/run-$label" --name "dtfs-mount-$label-v1519" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-mount-native-verify-v1519.s" \
        "$source" > "$work/$label.log" 2>&1
}

run_case baseline "$work/mount-source-v1519.s" || {
    tail -65 "$work/baseline.log" >&2
    exit 1
}
echo 'PASS v1519: native DTFS direct mount requires fresh physical directory'
for label in skip-physical-verification skip-cache-invalidation \
    wrong-magic-check skip-first-reserved skip-directory-reserved \
    skip-native-sentinels; do
    if run_case "$label" "$work/mutant-$label-v1519.s"; then
        echo "FAIL v1519: unsafe $label accepted" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$label.log" || {
        echo "FAIL v1519: $label did not execute the native failure oracle" >&2
        tail -34 "$work/$label.log" >&2
        exit 1
    }
    echo "PASS v1519: rejected $label source mutation"
done
