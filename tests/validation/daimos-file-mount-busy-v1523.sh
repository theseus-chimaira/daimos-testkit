#!/bin/sh
# Source-linked PDP-6 VFS unmount and actual stable-uarea FILE/cwd scan.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-file-mount-busy-v1523.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo, out = (Path(x) for x in sys.argv[1:])
vfs = (repo / 'system/kernel/fs/vfs.s').read_text()
file = (repo / 'system/kernel/fs/file_runtime.s').read_text()
vfs_unmount = vfs[vfs.index('vfs_unmount:\n'):
                  vfs.index('        .data\n; KINIT publishes both bases',
                            vfs.index('vfs_unmount:\n'))]
busy = file[file.index('file_mount_busy_v1523:\n'):
            file.index('; int file_close_all(void)', file.index(
                'file_mount_busy_v1523:\n'))]
required = (
    'pushj   17,vfs_unmount_owner_check_v1523',
    'vfs_unmount_after_prepare:\n',
    'pushj   17,pipe_fifo_mount_busy',
    'move    1,010\n        pushj   17,proc_swap_mount_busy',
    'move    1,010\n        pushj   17,file_mount_busy_v1523',
    'pushj   17,vfs_sync\n        jumpn   1,vfs_unmount_fail',
    'pushj   17,vfs_mount_retire_slot')
for anchor in required:
    assert anchor in vfs_unmount, anchor
for anchor in ('move    013,proc_high_slot',
               'trnn    2,0400000',
               'move    4,025(3)',
               'movei   6,026(3)',
               'movei   7,020'):
    assert anchor in busy, anchor

source = ('.text\n.globl vfs_unmount\n'
          '.globl file_mount_busy_v1523\n'
          + vfs_unmount + '\n' + busy)
(out / 'source-v1523.s').write_text(source)
mutations = (
    ('skip-file-check',
     'pushj   17,file_mount_busy_v1523',
     'pushj   17,kret_zero'),
    ('ignore-remote-process',
     'move    013,proc_high_slot',
     'movei   013,2'),
    ('ignore-cwd',
     'move    4,025(3)',
     'setz    4,'),
    ('ignore-last-fd',
     'movei   7,020                  ; FILE_NFILE, 16 entries',
     'movei   7,017                  ; FILE_NFILE, 16 entries'),
    ('wrong-swap-mount-id',
     'move    1,010\n        pushj   17,proc_swap_mount_busy',
     'movei   1,1(2)\n        pushj   17,proc_swap_mount_busy'),
    ('wrong-file-mount-id',
     'move    1,010\n        pushj   17,file_mount_busy_v1523',
     'movei   1,1(2)\n        pushj   17,file_mount_busy_v1523'),
    ('skip-precommit-check',
     'vfs_unmount_after_prepare:\n'
     '        ; SYNC and D6FS/MEMFS PREPARE may sleep.',
     'vfs_unmount_after_prepare:\n'
     '        jrst    vfs_unmount_precommit_bypass_v1523\n'
     '        ; SYNC and D6FS/MEMFS PREPARE may sleep.'),
)
for name, old, replacement in mutations:
    assert source.count(old) == 1, (name, source.count(old))
    if name == 'skip-precommit-check':
        replacement = replacement.replace(
            'vfs_unmount_precommit_bypass_v1523',
            'vfs_unmount_unlock')
    (out / ('mutant-' + name + '-v1523.s')).write_text(
        source.replace(old, replacement, 1))
PY

run_case() {
    name=$1
    input=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 280000 --timeout 20 \
        --workdir "$work/run-$name" --name "mount-refs-$name-v1523" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-file-mount-busy-v1523.s" "$input" \
        > "$work/$name.log" 2>&1
}
if ! run_case baseline "$work/source-v1523.s"; then
    tail -80 "$work/baseline.log" >&2
    echo 'FAIL v1523: real VFS/FILE busy baseline' >&2
    exit 1
fi
echo 'PASS v1523: all-process FILE/cwd unmount denial, clean close and retirement'
for name in skip-file-check ignore-remote-process ignore-cwd \
    ignore-last-fd wrong-swap-mount-id wrong-file-mount-id \
    skip-precommit-check; do
    if run_case "$name" "$work/mutant-$name-v1523.s"; then
        echo "FAIL v1523: accepted unsafe $name source mutation" >&2
        exit 1
    fi
    grep -q '^FAIL: __test_exit:' "$work/$name.log" || {
        echo "FAIL v1523: $name did not reach native oracle" >&2
        tail -50 "$work/$name.log" >&2
        exit 1
    }
    echo "PASS v1523: rejected native $name mutation"
done
