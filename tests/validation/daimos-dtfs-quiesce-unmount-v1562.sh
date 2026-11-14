#!/bin/sh
# Native v1562 actual VFS unmount, with simulated concurrent owner admission.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-quiesce-unmount-v1562.XXXXXX")
if [ "${V1562_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo, out = (Path(s) for s in sys.argv[1:])
vfs = (repo / 'system/kernel/fs/vfs.s').read_text()
start = vfs.index('vfs_unmount:\n')
end = vfs.index('; Validate a zero-based, currently published non-root DTFS',
                start)
source = '.text\n.globl vfs_unmount\n' + vfs[start:end]
assert source.count('pushj   17,vfs_dtfs_quiesce_begin_v1562') == 1
assert source.count('pushj   17,vfs_dtfs_quiesce_end_v1562') == 2
assert source.count('pushj   17,vfs_dtfs_owner_admit_v1562') == 0
assert source.count('trne    3,0620000') == 2

root, v2, seal = 0o050201000000, 0o100000, 0o020000
rd, wr = 0o200000, 0o400000
media = v2 | 3
cases = []

# root, media, retained-MM, sync-error, concurrent OPEN, initial FILE owner,
# expected return, expected root, expected media, sync count, OPEN result,
# unlock count, final owner.  Each case is a full actual VFS unmount path.
def case(label, initial=root, initial_media=media, aux=0, sync_error=0,
         open_attempt=0, busy=0, expected=0, final_root=0,
         final_media=None, sync_calls=1, attempt_result=0,
         unlocks=1, final_busy=None):
    if final_media is None:
        final_media = initial_media
    if final_busy is None:
        final_busy = busy
    fields = (initial, initial_media, aux, sync_error, open_attempt,
              busy, expected, final_root, final_media, sync_calls,
              attempt_result, unlocks, final_busy)
    assert len(fields) == 13
    cases.append((label, fields))

case('clean V2 seal closes and slot retires')
case('clean V2 concurrent OPEN refused', open_attempt=1,
     attempt_result=-1)
case('clean V2 failed SYNC aborts seal', sync_error=1,
     expected=-1, final_root=root, sync_calls=1, unlocks=0)
case('clean V2 failed SYNC rejects concurrent OPEN', sync_error=1,
     open_attempt=1, attempt_result=-1, expected=-1,
     final_root=root, unlocks=0)
case('V2 retained MM prevents SYNC', aux=0o12345,
     expected=-1, final_root=root, sync_calls=0, unlocks=0)
case('V2 READ_SUSPECT prevents SYNC', initial_media=media | rd,
     expected=-1, final_root=root, sync_calls=0, unlocks=0)
case('V2 WRITE_UNCERTAIN prevents SYNC', initial_media=media | wr,
     expected=-1, final_root=root, sync_calls=0, unlocks=0)
case('V2 preexisting seal cannot be borrowed',
     initial_media=media | seal, expected=-1, final_root=root,
     sync_calls=0, unlocks=0)
case('remote FILE owner prevents SYNC', busy=1, expected=-1,
     final_root=root, sync_calls=0, unlocks=0)
case('legacy V1 clean unmount unchanged', initial_media=3)
case('legacy V1 concurrent OPEN caught by final owner scan',
     initial_media=3, open_attempt=1, expected=-1, final_root=root,
     attempt_result=0, unlocks=0, final_busy=-1)
case('wrong published mount ID never sealed', initial=0o050301000000,
     expected=-1, final_root=0o050301000000, sync_calls=0,
     unlocks=0)

lines = ['.data\n.globl cases_v1562\n.globl case_count_v1562\n',
         '.equ case_count_v1562,0%o\n' % len(cases), 'cases_v1562:\n']
for label, fields in cases:
    lines.append('        ; %s\n' % label)
    lines.extend('        .word %s\n' % ('-1' if v == -1 else '0%012o' % v)
                 for v in fields)
(out / 'cases-v1562.s').write_text(''.join(lines))
(out / 'source-v1562.s').write_text(source)

mutants = (
    ('skip-begin',
     'pushj   17,vfs_dtfs_quiesce_begin_v1562',
     'pushj   17,kret_zero'),
    ('release-without-owner-recheck',
     'vfs_unmount_after_prepare:\n',
     'vfs_unmount_after_prepare:\n        jrst    vfs_unmount_aux_done_v1560\n'),
    ('do-not-block-new-owner',
     'trne    2,0020000', 'trnn    2,0020000'),
)
# The owner helper lives in the same VFS code segment. The current test
# catches a missing barrier both at the write-side acquisition and the
# sleeping-read-side publication attempt.
for label, old, new in mutants:
    assert source.count(old) == 1, (label, source.count(old))
    (out / ('mutant-' + label + '-v1562.s')).write_text(
        source.replace(old, new, 1))
print('v1562: %d full native unmount cases, %d source mutations' %
      (len(cases), len(mutants)))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 600000 --timeout 18 \
        --workdir "$work/run-$label" --name "dtfs-unmount-$label-v1562" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-quiesce-unmount-v1562.s" \
        "$work/cases-v1562.s" "$source" > "$work/$label.log" 2>&1
}
if ! run_case baseline "$work/source-v1562.s"; then
    tail -75 "$work/baseline.log" >&2
    echo 'FAIL v1562: complete native VFS quiescence/unmount' >&2
    exit 1
fi
echo 'PASS v1562: complete native V2/V1 unmount and owner race'
for mutant in skip-begin release-without-owner-recheck \
    do-not-block-new-owner; do
    if run_case "$mutant" "$work/mutant-$mutant-v1562.s"; then
        echo "FAIL v1562: accepted unsafe unmount mutation: $mutant" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutant.log" || {
        tail -30 "$work/$mutant.log" >&2
        echo "FAIL v1562: $mutant failed outside native oracle" >&2
        exit 1
    }
    echo "PASS v1562: rejected unsafe $mutant"
done
echo 'PASS v1562: owner-barrier during sleeping DTFS VFS unmount'
