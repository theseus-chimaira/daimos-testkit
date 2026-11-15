#!/bin/sh
# Native PDP-6 execution of ORIGINAL D6FS write-through, original BCACHE,
# original fs_backing DSK/DRM adapter and root-owner failure classifier.
# Only final physical controller completion is test-controlled.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-write-through-v1602.XXXXXX")
if [ "${V1602_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1602 native evidence: $work"
fi

python3 - "$DAIMOS_REPO" "$self" "$work" <<'PY'
from pathlib import Path
import sys

repo, self, work = (Path(item) for item in sys.argv[1:])
runtime = (repo / 'system/kernel/fs/d6fs_runtime.s').read_text()
adapter = (repo / 'system/kernel/storage/fs_backing.s').read_text()
gate = (repo / 'system/kernel/proc/proc_storage_runtime_v30.s').read_text()
cache = (repo / 'system/kernel/storage/bcache_pdp6.s').read_text()
fixture = (self / 'daimos-p1c-write-through-cache-v1602.s').read_text()

def extract(source, start, end):
    assert source.count(start) == 1 and source.count(end) == 1
    return source[source.index(start):source.index(end)]

restore = extract(runtime, 'd6fs_restore3:\n',
                  '        .globl  d6fs_reader_commit_cache\n')
commit = extract(runtime, 'd6fs_reader_commit_cache:\n',
                 '        .globl  d6fs_reader_write_block\n')
assert commit.count('pushj   17,bcache_workspace_invalidate') == 1
assert commit.count('pushj   17,fs_backing_write') == 1
assert commit.count('pushj   17,bcache_store') == 1
assert commit.count('pushj   17,kcore_root_fs_io_failure_v1538') == 1
assert commit.index('bcache_workspace_invalidate') < \
    commit.index('fs_backing_write') < commit.index('bcache_store')
assert gate.count('kcore_root_fs_io_failure_v1538:\n') == 1
assert cache.count('bcache_state:') == 1
assert cache.count('bcache_workspace_tag:') == 1
linked = ('.text\n.globl d6fs_reader_commit_cache\n'
          '.globl kcore_critical_media_root_halt_v1515\n'
          '.globl kcore_critical_media_swap_halt_v1515\n'
          + restore + commit + adapter +
          gate[gate.index('kcore_root_fs_io_failure_v1538:\n'):]
          + '\n.globl bcache_state\n.globl bcache_workspace_tag\n'
          + cache)
(work / 'source-v1602.s').write_text(linked)

cases = []
for kind, selector in (('dsk', '2,,0100'),
                       ('drm', '0400003,,0400')):
    for fail in (True, False):
        name = kind + ('-failed' if fail else '-success')
        rendered = fixture.replace('test_kind_v1602: .word 1',
                                   'test_kind_v1602: .word ' +
                                   ('1' if kind == 'dsk' else '2'))
        rendered = rendered.replace('test_fail_io_v1602: .word 1',
                                    'test_fail_io_v1602: .word ' +
                                    ('1' if fail else '0'))
        rendered = rendered.replace('secondary_selector_v1602: .word 2,,0100',
                                    'secondary_selector_v1602: .word ' + selector)
        (work / ('case-' + name + '-v1602.s')).write_text(rendered)
        cases.append(name)

mutants = (
    ('skip-prewrite-invalidate',
     'pushj   17,bcache_workspace_invalidate',
     'pushj   17,kret_zero', 'dsk-failed'),
    ('invalidate-independent-clean-slab',
     'pushj   17,bcache_workspace_invalidate',
     'pushj   17,bcache_invalidate_all', 'drm-failed'),
    ('forge-failed-write-as-success',
     'jumpn   1,d6fs_reader_commit_io_error_v1538',
     'jumpe   1,d6fs_reader_commit_io_error_v1538', 'dsk-failed'),
    ('misclassify-secondary-as-root',
     'move    2,1(010)                ; actual writing reader\'s mount ID',
     'movei   2,1                     ; unsafe forced root', 'drm-failed'),
    ('publish-clean-on-failed-write',
     'jumpn   1,d6fs_reader_commit_io_error_v1538',
     'jumpn   1,d6fs_reader_commit_cache_bad_v1602', 'drm-failed'),
)
for name, old, new, case in mutants:
    assert linked.count(old) == 1, 'source changed for mutant ' + name
    changed = linked.replace(old, new, 1)
    if name == 'publish-clean-on-failed-write':
        # Deliberately insert a valid-looking clean tag even though the
        # physical WRITE returned an error, then preserve the original
        # owner classifier.  The unmodified native BCACHE oracle must
        # catch this false clean publication.
        anchor = 'd6fs_reader_commit_io_error_v1538:\n'
        helper = ('d6fs_reader_commit_cache_bad_v1602:\n'
                  '        move    1,012\n'
                  '        movei   2,fs_block_workspace\n'
                  '        pushj   17,bcache_store\n'
                  '        jrst    d6fs_reader_commit_io_error_v1538\n')
        assert changed.count(anchor) == 1
        changed = changed.replace(anchor, helper + anchor, 1)
    (work / ('mutant-' + name + '-v1602.s')).write_text(changed)
    (work / ('mutant-case-' + name + '.txt')).write_text(case)
(work / 'cases-v1602.txt').write_text('\n'.join(cases) + '\n')
print('v1602: source-linked real D6FS, BCACHE, adapter, root owner; '
      '%d cases and %d executable corruptions' %
      (len(cases), len(mutants)))
PY

run_case() {
    label=$1
    case=$2
    source=$3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 230000 --timeout 20 \
        --workdir "$work/run-$label" --name "d6write-$label-v1602" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$work/case-$case-v1602.s" "$source" \
        > "$work/$label.log" 2>&1
}

while IFS= read -r name; do
    if ! run_case "$name" "$name" "$work/source-v1602.s"; then
        tail -68 "$work/$name.log" >&2
        exit 1
    fi
    echo "PASS v1602: $name real clean-only write-through/owner isolation"
done < "$work/cases-v1602.txt"

for mutant in skip-prewrite-invalidate \
    invalidate-independent-clean-slab \
    forge-failed-write-as-success misclassify-secondary-as-root \
    publish-clean-on-failed-write; do
    case=$(cat "$work/mutant-case-$mutant.txt")
    if run_case "mutant-$mutant" "$case" \
        "$work/mutant-$mutant-v1602.s"; then
        echo "FAIL v1602: unsafe source mutation accepted: $mutant" >&2
        exit 1
    fi
    echo "PASS v1602: rejected $mutant"
done
echo 'PASS v1602: native D6FS/BCACHE/physical DSK+DRM fault isolation'
