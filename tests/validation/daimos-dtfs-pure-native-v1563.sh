#!/bin/sh
# Compiled PDP-6 C attach with actual v1562 assembly gate, no model logic.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-pure-native-v1563.XXXXXX")
if [ "${V1563_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
includes="-I$PDP10_PREFIX/include"
for d in boot core drivers fs ipc mm modules proc storage; do
    includes="$includes -I$DAIMOS_REPO/system/kernel/$d"
done

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo, work = (Path(x) for x in sys.argv[1:])
vfs = (repo / 'system/kernel/fs/vfs.s').read_text()
start = vfs.index('vfs_dtfs_owner_admit_v1562:\n')
end = vfs.index('; v1562: acquire a temporary', start)
gate = '.text\n.globl vfs_dtfs_owner_admit_v1562\n' + vfs[start:end]
(work / 'gate-v1563.s').write_text(gate)
assert gate.count('trne    2,0020000') == 1
(work / 'gate-unsafe-v1563.s').write_text(
    gate.replace('trne    2,0020000', 'trnn    2,0020000', 1))

def node(provider=5, mount=1, kind=2, index=0o12345):
    return ((provider << 30) | ((mount * 64 + kind) << 18) | index)

def sched(state=1, bit=0):
    return (state << 33) | (0o24 << 18) | bit

def packed():
    return (0o12345 | (0o700 << 22))

# vnode, root, media, has-uarea, sched, cred, record-before,
# expected result, record-after, credential-after, sched-after.
cases = []
def case(label, state=1, has_uarea=0, staged_bit=0, cred=0,
         media=0o100003, root=None, expected=0):
    if root is None:
        root = node(kind=1, index=0)
    before = 0o1234567
    after = packed() if expected == 0 else before
    aftercred = cred
    if has_uarea and expected == 0:
        aftercred &= ~0o001000000000
    afterstage = staged_bit
    if state == 1 and expected == 0:
        afterstage = 0
    fields = [node(), root, media, has_uarea, sched(state, staged_bit),
              cred, before, expected, after, aftercred,
              sched(state, afterstage)]
    cases.append((label, fields))

case('SIDL without uarea admitted')
case('SIDL with uarea admitted', has_uarea=1)
case('SIDL with stale staged bit cleared', has_uarea=1,
     staged_bit=1, cred=0o001000000000)
case('SRUN with stable uarea admitted', state=2, has_uarea=1)
case('SRUN retains runnable link', state=2, has_uarea=1, staged_bit=1)
case('quiescent SIDL no uarea refused', media=0o120003, expected=-1)
case('quiescent SIDL with uarea refused', media=0o120003,
     has_uarea=1, staged_bit=1, cred=0o001000000000,
     expected=-1)
case('quiescent SRUN with uarea refused', media=0o120003,
     state=2, has_uarea=1, expected=-1)
case('retired mount refused', root=0, expected=-1)
case('reused provider refused', root=node(provider=6, kind=1,
     index=0), expected=-1)
case('reused public mount ID refused', root=node(mount=2, kind=1,
     index=0), expected=-1)

lines = ['.data\n.globl cases_v1563\n.globl case_count_v1563\n',
         '.equ case_count_v1563,0%o\n' % len(cases),
         'cases_v1563:\n']
for label, fields in cases:
    assert len(fields) == 11
    lines.append('        ; %s\n' % label)
    lines.extend('        .word %s\n' %
                 ('-1' if value == -1 else '0%012o' % value)
                 for value in fields)
(work / 'cases-v1563.s').write_text(''.join(lines))
source = (repo / 'system/kernel/proc/proc_pure_attach.c').read_text()
assert source.count('vfs_dtfs_owner_admit_v1562(backing) != 0') == 1
(work / 'attach-unsafe-v1563.c').write_text(source.replace(
    'vfs_dtfs_owner_admit_v1562(backing) != 0',
    'vfs_dtfs_owner_admit_v1562(backing) == 0', 1))
print('v1563: %d source-linked native attachment cases, 2 mutants' %
      len(cases))
PY

# shellcheck disable=SC2086
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $includes \
    -S "$DAIMOS_REPO/system/kernel/proc/proc_pure_attach.c" \
    -o "$work/attach-v1563.s"
# shellcheck disable=SC2086
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $includes \
    -S "$work/attach-unsafe-v1563.c" -o "$work/attach-unsafe-v1563.s"

run_case() {
    label=$1
    attach=$2
    gate=$3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 450000 --timeout 20 \
        --workdir "$work/run-$label" --name "dtfs-attach-$label-v1563" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-pure-native-v1563.s" \
        "$work/cases-v1563.s" "$attach" "$gate" \
        > "$work/$label.log" 2>&1
}
if ! run_case baseline "$work/attach-v1563.s" "$work/gate-v1563.s"; then
    tail -80 "$work/baseline.log" >&2
    echo 'FAIL v1563: real KCC attach and VFS gate' >&2
    exit 1
fi
echo 'PASS v1563: real PDP-6 C attach and VFS barrier'
if run_case reversed-attach "$work/attach-unsafe-v1563.s" \
    "$work/gate-v1563.s"; then
    echo 'FAIL v1563: accepted unsafe reversed attachment gate' >&2
    exit 1
fi
grep -q 'FAIL: __test_exit:' "$work/reversed-attach.log" || exit 1
echo 'PASS v1563: rejected reversed attachment gate'
if run_case reversed-media "$work/attach-v1563.s" \
    "$work/gate-unsafe-v1563.s"; then
    echo 'FAIL v1563: accepted unsafe media bit test' >&2
    exit 1
fi
grep -q 'FAIL: __test_exit:' "$work/reversed-media.log" || exit 1
echo 'PASS v1563: rejected reversed media bit test'
