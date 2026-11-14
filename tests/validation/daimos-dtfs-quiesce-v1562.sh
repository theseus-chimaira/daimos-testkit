#!/bin/sh
# v1562: source-linked PDP-6 DTFS owner publication and quiescence tests.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-quiesce-v1562.XXXXXX")
if [ "${V1562_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo, work = (Path(s) for s in sys.argv[1:])
vfs = (repo / 'system/kernel/fs/vfs.s').read_text()
file_src = (repo / 'system/kernel/fs/file_runtime.s').read_text()
dtfs_src = (repo / 'system/kernel/fs/dtfs_runtime.s').read_text()
bridge_src = (repo / 'system/kernel/fs/dtfs_intent_mount_gate_v1561.s').read_text()

def leaf(start, stop):
    assert vfs.count(start) == 1, start
    assert vfs.count(stop) == 1, stop
    return start + vfs.split(start, 1)[1].split(stop, 1)[0]

source = (
    '.text\n.globl vfs_dtfs_aux_empty_v1560\n'
    '.globl vfs_dtfs_owner_admit_v1562\n'
    '.globl vfs_dtfs_quiesce_begin_v1562\n'
    '.globl vfs_dtfs_quiesce_end_v1562\n'
    + leaf('vfs_dtfs_aux_empty_v1560:\n', '; v1562: mount-owner')
    + leaf('vfs_dtfs_owner_admit_v1562:\n', '; v1562: acquire')
    + leaf('vfs_dtfs_quiesce_begin_v1562:\n', '; Release only the barrier')
    + leaf('vfs_dtfs_quiesce_end_v1562:\n', '; Validate a zero-based,')
)

# Do not accept an isolated helper if the actual VFS and MRES hooks bypass it.
assert file_src.count('pushj   17,vfs_dtfs_owner_admit_v1562') == 2
assert dtfs_src.count('pushj   17,vfs_dtfs_owner_admit_v1562') == 1
assert bridge_src.count('trne    015,0020000') == 1
for name in ('vfs_dtfs_quiesce_begin_v1562',
             'vfs_dtfs_quiesce_end_v1562'):
    assert vfs.count('pushj   17,' + name) >= 1
assert vfs.index('pushj   17,vfs_unmount_owner_check_v1523',
                 vfs.index('vfs_unmount_slot:')) < vfs.index(
                     'pushj   17,vfs_dtfs_quiesce_begin_v1562') < vfs.index(
                     'pushj   17,vfs_sync', vfs.index('vfs_unmount_slot:'))
assert vfs.index('pushj   17,vfs_dtfs_quiesce_end_v1562') < vfs.index(
    'pushj   17,vfs_mount_retire_slot', vfs.index('vfs_unmount_slot:'))

r0, r1 = 0o050101000000, 0o050201000000
v2, seal = 0o100000, 0o020000
suspect, uncertain = 0o200000, 0o400000
base = v2 | 3

# Native case fields: mode, argument, root[0:2], media[0:2], aux[0:2],
# limit, missing flags, expected return, expected media[0:2].
cases = []
def case(label, mode, arg=0, roots=(r0, 0), media=(base, 0),
         aux=(0, 0), limit=2, flags=0, expected=0,
         expected_media=None):
    if expected_media is None:
        expected_media = media
    cases.append((label, [mode, arg, *roots, *media, *aux, limit,
                          flags, expected, *expected_media]))

# Mount-admission check (mode 0): vnode or packed FILE descriptor.
case('V2 normal root vnode allowed', 0, r0)
case('V2 ordinary file vnode allowed', 0, 0o050102000010)
case('V2 sealed root refused', 0, r0, media=(base | seal, 0), expected=-1)
case('V2 sealed file refused', 0, 0o050102000010,
     media=(base | seal, 0), expected=-1)
case('V2 sealed packed READ FILE refused', 0, 0o450102000010,
     media=(base | seal, 0), expected=-1)
case('V2 sealed packed WRITE FILE refused', 0, 0o250102000010,
     media=(base | seal, 0), expected=-1)
case('V1 legacy unaffected', 0, r0, media=(3, 0))
case('another provider unaffected', 0, 0o060101000000,
     media=(base | seal, 0))
case('V2 second mount admitted', 0, r1,
     roots=(0, r1), media=(0, base))
case('V2 second mount sealed refused', 0, r1,
     roots=(0, r1), media=(0, base | seal), expected=-1)
case('retired mount refused', 0, r0, roots=(0, 0), expected=-1)
case('recycled wrong provider refused', 0, r0,
     roots=(0o060101000000, 0), expected=-1)
case('recycled wrong mount ID refused', 0, r0, roots=(r1, 0),
     expected=-1)
case('out-of-range mount ID refused', 0, r1, limit=1, expected=-1)
case('unpublished mount ID refused', 0, 0o050001000000, expected=-1)
case('missing root table refused', 0, r0, flags=1, expected=-1)
case('missing media table refused', 0, r0, flags=2, expected=-1)

# Quiescence acquisition (mode 1), zero-based mount slot.
case('clean V2 begins', 1, expected=1,
     expected_media=(base | seal, 0))
case('V2 second slot begins', 1, 1, roots=(0, r1),
     media=(0, base), expected=1, expected_media=(0, base | seal))
case('V2 retained scratch refused', 1, aux=(0o1234, 0), expected=-1)
case('V2 other scratch unaffected', 1, aux=(0, 0o1234), expected=1,
     expected_media=(base | seal, 0))
case('V2 missing aux slab refused', 1, flags=4, expected=-1)
case('V2 preexisting seal refused', 1, media=(base | seal, 0),
     expected=-1)
case('V2 read-suspect refused', 1, media=(base | suspect, 0),
     expected=-1)
case('V2 write-uncertain refused', 1, media=(base | uncertain, 0),
     expected=-1)
case('V2 combined failure refused', 1,
     media=(base | suspect | uncertain, 0), expected=-1)
case('V1 legacy begin bypass', 1, media=(3, 0))
case('D6FS begin bypass', 1, roots=(0o060101000000, 0))
case('no published slot begin refused', 1, roots=(0, 0), expected=-1)
case('V2 wrong mount ID begin refused', 1, roots=(r1, 0), expected=-1)
case('V2 missing media begin refused', 1, flags=2, expected=-1)
case('V2 invalid slot begin refused', 1, arg=2, expected=-1)

# End barrier (mode 2): only exact original published owner may clear it.
case('original V2 end clears seal', 2, media=(base | seal, 0),
     expected_media=(base, 0))
case('second V2 end clears seal', 2, arg=1, roots=(0, r1),
     media=(0, base | seal), expected_media=(0, base))
case('original V2 end retains fault bits', 2,
     media=(base | seal | suspect, 0),
     expected_media=(base | suspect, 0))
case('wrong expected root cannot clear', 2,
     media=(base | seal, 0), flags=8, expected=-1)
case('wrong provider cannot clear', 2,
     roots=(0o060101000000, 0), media=(base | seal, 0), expected=-1)
case('not sealed cannot end', 2, expected=-1)
case('unpublished mount cannot end', 2, roots=(0, 0),
     media=(base | seal, 0), expected=-1)
case('missing media cannot end', 2, media=(base | seal, 0),
     flags=2, expected=-1)
case('out-of-range end refused', 2, arg=2, media=(base | seal, 0),
     expected=-1)

lines = ['.data\n.globl cases_v1562\n.globl case_count_v1562\n',
         '.equ case_count_v1562,0%o\n' % len(cases),
         'cases_v1562:\n']
for label, values in cases:
    assert len(values) == 13, (label, values)
    lines.append('        ; %s\n' % label)
    lines.extend('        .word %s\n' % ('-1' if v == -1 else '0%012o' % v)
                 for v in values)
(work / 'cases-v1562.s').write_text(''.join(lines))

mutants = (
    ('allow-sealed-owner', 'trne    2,0020000', 'trnn    2,0020000'),
    ('allow-retired-owner', 'skipn   2,(5)', 'skipe   2,(5)'),
    ('ignore-retained-MM',
     'jumpn   1,vfs_dtfs_quiesce_bad_v1562',
     'jumpe   1,vfs_dtfs_quiesce_bad_v1562'),
    ('do-not-arm-barrier', 'tro     3,0020000', 'trz     3,0020000'),
    ('ignore-seal-on-end', 'trnn    4,0020000', 'trne    4,0020000'),
    ('ignore-owner-on-end', 'came    4,2', 'came    4,4'),
    ('leave-barrier-set', 'trz     4,0020000', 'tro     4,0020000'),
)
for label, old, new in mutants:
    assert source.count(old) == 1, (label, source.count(old))
    (work / ('mutant-' + label + '-v1562.s')).write_text(
        source.replace(old, new, 1))
(work / 'production-v1562.s').write_text(source)
print('v1562: %d native cases, %d unsafe source mutations' %
      (len(cases), len(mutants)))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 420000 --timeout 18 \
        --workdir "$work/run-$label" --name "dtfs-quiesce-$label-v1562" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-quiesce-v1562.s" \
        "$work/cases-v1562.s" "$source" > "$work/$label.log" 2>&1
}
if ! run_case baseline "$work/production-v1562.s"; then
    tail -75 "$work/baseline.log" >&2
    echo 'FAIL v1562: native quiescence and owner admission' >&2
    exit 1
fi
echo 'PASS v1562: native V2 owner/quiescence cases'
for mutant in allow-sealed-owner allow-retired-owner ignore-retained-MM \
    do-not-arm-barrier ignore-seal-on-end ignore-owner-on-end \
    leave-barrier-set; do
    if run_case "$mutant" "$work/mutant-$mutant-v1562.s"; then
        echo "FAIL v1562: accepted unsafe mutant: $mutant" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutant.log" || {
        tail -35 "$work/$mutant.log" >&2
        echo "FAIL v1562: mutant failed outside native oracle: $mutant" >&2
        exit 1
    }
    echo "PASS v1562: rejected $mutant"
done
echo 'PASS v1562: actual KCORE V2 quiescence admission and lifecycle'
