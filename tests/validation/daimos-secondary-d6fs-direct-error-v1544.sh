#!/bin/sh
# Native PDP-6 D6FS->fs_backing->DSK/DRM adapter->controller-failure matrix.
# Only physical completion and BCACHE are mocked; all owner/mapping/error
# dispatch source is taken unmodified from the current DAIMOS checkout.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-secondary-d6fs-v1544.XXXXXX")
if [ "${V1544_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$self" "$work" <<'PY'
from pathlib import Path
import sys

repo, tests, work = (Path(arg) for arg in sys.argv[1:])
runtime = (repo / 'system/kernel/fs/d6fs_runtime.s').read_text()
adapter = (repo / 'system/kernel/storage/fs_backing.s').read_text()
gate_source = (repo / 'system/kernel/proc/proc_storage_runtime_v30.s').read_text()

def extract(src, first, last):
    assert src.count(first) == 1 and src.count(last) == 1, (first, last)
    return src[src.index(first):src.index(last)]

read = extract(runtime, 'd6fs_reader_get_block:\n',
               '        .globl  d6fs_reader_fcb\n')
restore = extract(runtime, 'd6fs_restore3:\n',
                  '        .globl  d6fs_reader_commit_cache\n')
write = extract(runtime, 'd6fs_reader_commit_cache:\n',
                '        .globl  d6fs_reader_write_block\n')
gate = gate_source[gate_source.index('kcore_root_fs_io_failure_v1538:\n'):]
assert read.count('pushj   17,kcore_root_fs_io_failure_v1538') == 1
assert write.count('pushj   17,kcore_root_fs_io_failure_v1538') == 1
assert adapter.count('fs_backing_direct_drm_read_jump:') == 1
assert adapter.count('fs_backing_direct_root_drm_write_call:') == 1
assert gate.count('halt    .') == 3
source = ('.text\n.globl d6fs_reader_get_block\n'
          '.globl d6fs_reader_commit_cache\n'
          '.globl kcore_critical_media_root_halt_v1515\n'
          '.globl kcore_critical_media_swap_halt_v1515\n'
          + read + restore + write + adapter + gate)
(work / 'linked-v1544.s').write_text(source)

# Actual D6FS root public mount 1 and secondary mount 2. Each opaque
# carries the physical controller selector and the physical block base.
# The root flag is intentionally absent from every secondary descriptor.
root = {'dsk': '0100000,,0200', 'drm': '0500001,,0300'}
secondary = {
    'dsk': '2,,0100', 'drm': '0400003,,0400',
    'dsk-set': '0200015,,0100', 'drm-set': '0600015,,0100',
}
device = {
    'root-dsk': (1,0,0o205),
    'root-drm': (2,1,0o305),
    'secondary-dsk': (1,2,0o105),
    'secondary-drm': (2,3,0o405),
    'secondary-dsk-set': (1,3,0o101),
    'secondary-drm-set': (2,3,0o101),
}
fixture = (tests / 'daimos-secondary-d6fs-direct-error-v1544.s').read_text()
anchors = {
    'reader': 'test_reader_v1544: .word ',
    'block': 'test_block_v1544: .word ',
    'write': 'test_write_v1544: .word ',
    'failed': 'test_io_failed_v1544: .word ',
    'result': 'test_expected_v1544: .word ',
    'stores': 'test_stores_v1544: .word ',
    'root': 'root_selector_v1544: .word ',
    'secondary': 'secondary_selector_v1544: .word ',
}

cases = []
for kind in ('dsk', 'drm'):
    for owner in ('root', 'secondary'):
        for op in ('read', 'write'):
            cases.append((owner + '-' + kind + '-' + op + '-fail',
                          owner, kind, op, True, False, False))
        for op in ('read', 'write'):
            cases.append((owner + '-' + kind + '-' + op + '-success',
                          owner, kind, op, False, False, False))
for kind in ('dsk-set', 'drm-set'):
    for op in ('read', 'write'):
        cases.append(('secondary-' + kind + '-' + op + '-fail',
                      'secondary', kind, op, True, False, False))
cases.extend((
    ('secondary-dsk-out-of-range','secondary','dsk','read',True,True,False),
    ('secondary-drm-out-of-range','secondary','drm','write',True,True,False),
    ('root-dsk-out-of-range','root','dsk','read',True,True,False),
    ('root-drm-out-of-range','root','drm','write',True,True,False),
))

for label, owner, kind, op, failed, out_of_range, _ in cases:
    is_root = owner == 'root'
    physical_kind, unit, block = device[owner + '-' + kind]
    if is_root:
        expect_selector = root[kind]
        other_selector = secondary['dsk']
    else:
        expect_selector = secondary[kind]
        other_selector = root['dsk']
    if out_of_range:
        result = '0' if op == 'read' else '-1'
    elif failed:
        result = '0' if op == 'read' else '-1'
    elif op == 'read':
        result = 'fs_block_workspace'
    else:
        result = '0'
    values = {
        'reader': owner + '_reader_v1544',
        'block': '0100' if out_of_range else '5',
        'write': '1' if op == 'write' else '0',
        'failed': '1' if failed else '0',
        'result': result,
        'stores': '0' if failed or out_of_range else '1',
        'root': expect_selector if is_root else other_selector,
        'secondary': other_selector if is_root else expect_selector,
    }
    rendered = fixture
    for field, anchor in anchors.items():
        assert rendered.count(anchor) == 1, (label, field)
        start = rendered.index(anchor) + len(anchor)
        end = rendered.index('\n', start)
        rendered = rendered[:start] + values[field] + rendered[end:]
    (work / ('case-' + label + '-v1544.s')).write_text(rendered)
    io = 0 if out_of_range else 1
    expected = [
        '__test_exit=' + ('1' if is_root and failed and not out_of_range else '0'),
        'read_count_v1544=' + str(io),
        'seen_kind_v1544=' + str(physical_kind if io else 0),
        'seen_unit_v1544=' + str(unit if io else 0),
        'seen_block_v1544=' + ('0%o' % block if io else '0'),
        'root_error_count_v1544=' + ('1' if is_root and failed and io else '0'),
    ]
    if not is_root:
        expected += ['mfsdev_d6set_reads=0', 'mfsdev_d6set_writes=0']
    elif not failed and not out_of_range:
        expected.append('mfsdev_d6set_' + ('writes' if op == 'write' else 'reads') + '=1')
    (work / ('expect-' + label + '-v1544.txt')).write_text('\n'.join(expected)+'\n')

mutations = (
    ('no-root-read-gate',
     'pushj   17,kcore_root_fs_io_failure_v1538\n        ; Only non-root',
     'pushj   17,kret_neg1\n        ; Only non-root',
     'root-dsk-read-fail'),
    ('secondary-is-root',
     'camn    1,2\n        jrst    kcore_root_fs_io_halt_v1538',
     'came    1,2\n        jrst    kcore_root_fs_io_halt_v1538',
     'secondary-dsk-read-fail'),
    ('misroute-drm-as-dsk',
     'trne    6,0400000\n        jrst    fs_backing_direct_drm',
     'trnn    6,0400000\n        jrst    fs_backing_direct_drm',
     'secondary-drm-read-fail'),
    ('mislabel-secondary-as-root',
     'trne    6,0100000               ; boot-root logical request?',
     'trnn    6,0100000               ; boot-root logical request?',
     'secondary-dsk-read-fail'),
    ('wrong-root-halt-reason',
     'kcore_root_fs_io_halt_v1538:\n        movei   1,1',
     'kcore_root_fs_io_halt_v1538:\n        movei   1,2',
     'root-drm-read-fail'),
    ('wrong-interleave-ordinal',
     'sojl    1,fs_backing_direct_dispatch',
     'sojle   1,fs_backing_direct_dispatch',
     'secondary-drm-set-read-fail'),
)
for name, old, new, case in mutations:
    assert source.count(old) == 1, (name,source.count(old))
    (work / ('mutant-' + name + '-v1544.s')).write_text(source.replace(old,new,1))
    (work / ('mutant-case-' + name + '-v1544.txt')).write_text(case)

(work / 'all-cases-v1544.txt').write_text('\n'.join(c[0] for c in cases)+'\n')
print('v1544: prepared %d physical-adapter native cases, %d source mutants' %
      (len(cases), len(mutations)))
PY

run_case() {
    label=$1
    case=$2
    linked=$3
    shift 3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 100000 \
        --timeout 15 --workdir "$work/run-$label" \
        --name "d6direct-$label-v1544" "$@" \
        "$self/daimos-test-crt0-v1.s" \
        "$work/case-$case-v1544.s" "$linked" \
        > "$work/$label.log" 2>&1
}

check_root_pc() {
    label=$1
    python3 - "$work/run-$label/d6direct-$label-v1544.report.txt" \
        "$work/run-$label/d6direct-$label-v1544.labels" <<'PY'
from pathlib import Path
import re
import sys
report, labels = (Path(f).read_text() for f in sys.argv[1:])
halt = re.search(r'HALT instruction, PC: ([0-7]{6})', report)
assert halt, 'no hardware HALT'
syms = dict(re.findall(r'(?m)^(\S+)\s+([0-7]{6})\s*$',labels))
assert halt.group(1) == syms['kcore_critical_media_root_halt_v1515']
assert halt.group(1) != syms['kcore_critical_media_swap_halt_v1515']
PY
}

while IFS= read -r name; do
    set --
    while IFS= read -r expected; do
        set -- "$@" --expect "$expected"
    done < "$work/expect-$name-v1544.txt"
    if ! run_case "$name" "$name" "$work/linked-v1544.s" "$@"; then
        tail -45 "$work/$name.log" >&2
        exit 1
    fi
    case "$name" in
        root-*-fail) case "$name" in *out-of-range*) ;; *) check_root_pc "$name" ;; esac ;;
    esac
    echo "PASS v1544: $name"
done < "$work/all-cases-v1544.txt"

for name in no-root-read-gate secondary-is-root misroute-drm-as-dsk \
    mislabel-secondary-as-root wrong-root-halt-reason wrong-interleave-ordinal; do
    case=$(cat "$work/mutant-case-$name-v1544.txt")
    set --
    while IFS= read -r expected; do
        set -- "$@" --expect "$expected"
    done < "$work/expect-$case-v1544.txt"
    if run_case "mutant-$name" "$case" "$work/mutant-$name-v1544.s" "$@"; then
        if [ "$name" = wrong-root-halt-reason ] && \
           ! check_root_pc "mutant-$name" >/dev/null 2>&1; then
            echo 'PASS v1544: rejected wrong-root-halt-reason'
            continue
        fi
        echo "FAIL v1544: unsafe source mutant accepted: $name" >&2
        exit 1
    fi
    echo "PASS v1544: rejected $name"
done
echo 'PASS v1544: D6FS root/secondary physical DSK/DRM adapter isolation'
