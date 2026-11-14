#!/bin/sh
# v1563: source-linked native PDP-6 PURE staging and stable mount guards.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-pure-staging-v1563.XXXXXX")
if [ "${V1563_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo, work = (Path(x) for x in sys.argv[1:])
swap = (repo / 'system/kernel/proc/proc_pure_backing_pdp6.s').read_text()
start = swap.index('proc_swap_backing_busy:\n')
source = ('.text\n.globl proc_swap_backing_busy\n'
          '.globl proc_swap_mount_busy\n'
          '.equ PROC_SWAP_BACKING_OFFSET,0406\n'
          '.equ PROC_SWAP_MOUNT_SHIFT,022\n'
          '.equ PROC_SWAP_TEXT_SHIFT,026\n'
          '.equ PROC_SWAP_TEXT_MASK,037777\n'
          + swap[start:])
assert source.count('proc_swap_backing_stable_v1563:') == 1
assert source.count('proc_swap_mount_stable_v1563:') == 1

def vnode(mount, index=0o12345):
    return ((5 << 30) | ((mount * 64 + 2) << 18) | index)

def record(mount, text=0o700, index=0o12345):
    return (index | (((mount - 1) & 0o17) << 18) |
            (text << 22))

def sched(state, fifth=0):
    return ((state << 33) | (0o24 << 18) | fifth)

cases = []
def case(label, mode, arg, mount=1, state=1, fifth=0,
         has_uarea=0, vm=0, cred=0, text=0o700,
         saved=0, expected=1):
    fields = [mode, arg, sched(state, fifth), has_uarea, vm,
              cred, record(mount, text), saved, expected]
    assert len(fields) == 9
    cases.append((label, fields))

# Mode 0 checks physical public mount owners. In-flight SIDL must count
# even before UAREA exists and after UAREA is attached but zeroed.
case('SIDL PURE without uarea blocks mount 1', 0, 1)
case('SIDL PURE without uarea blocks mount 2', 0, 2, mount=2)
case('SIDL PURE without uarea blocks mount 16', 0, 16, mount=16)
case('SIDL PURE high bit blocks mount 17', 0, 17, mount=17, fifth=1)
case('SIDL PURE high bit blocks mount 26', 0, 26, mount=26, fifth=1)
case('SIDL high bit no uarea rejects other mount', 0, 1,
     mount=17, fifth=1, expected=0)
case('SIDL high bit wrong staged bit does not match 17', 0, 17,
     mount=17, fifth=0, expected=0)
case('SIDL high bit after empty uarea blocks 17', 0, 17,
     mount=17, fifth=1, has_uarea=1, vm=0o2345, cred=0)
case('SIDL after uarea ignores stale credential bit', 0, 1,
     mount=1, fifth=0, has_uarea=1, vm=0o2345, cred=1)
case('SIDL no PURE text is not backing owner', 0, 1,
     text=0, expected=0)
case('SIDL other mount not busy', 0, 2, mount=1, expected=0)
case('SRUN without uarea is not an owner', 0, 1,
     state=2, expected=0)
case('SRUN uarea resident own mount', 0, 1,
     state=2, has_uarea=1, vm=0o2345)
case('SRUN uarea resident high mount', 0, 26, mount=26,
     state=2, has_uarea=1, vm=0o2345, cred=1)
case('SRUN wrong credential fifth bit does not match', 0, 26,
     mount=26, state=2, has_uarea=1, vm=0o2345, cred=0,
     expected=0)
case('SRUN swapped PURE saved uarea record', 0, 2, mount=2,
     state=2, has_uarea=1, vm=0, text=0,
     saved=record(2), expected=1)
case('SRUN nonPURE text ignored', 0, 1, state=2, has_uarea=1,
     vm=0o2345, text=0, expected=0)

# Mode 1 checks vnode immutability, using the same native record and
# SIDL extension source as mount-owner scans.
case('SIDL PURE vnode unchanged during RUN', 1, vnode(1))
case('SIDL PURE high vnode protects 17', 1, vnode(17),
     mount=17, fifth=1)
case('SIDL PURE high vnode protects 26', 1, vnode(26),
     mount=26, fifth=1, has_uarea=1, vm=0o2345)
case('SIDL PURE other vnode not busy', 1, vnode(2), expected=0)
case('SIDL PURE wrong staged bit not match 17', 1, vnode(17),
     mount=17, fifth=0, expected=0)
case('SIDL no PURE text not busy', 1, vnode(1),
     text=0, expected=0)
case('SRUN resident PURE vnode protected', 1, vnode(1),
     state=2, has_uarea=1, vm=0o2345)
case('SRUN swapped saved PURE vnode protected', 1, vnode(1),
     state=2, has_uarea=1, vm=0, text=0,
     saved=record(1))
case('SRUN incorrect vnode index not busy', 1, vnode(1, 0o23456),
     state=2, has_uarea=1, vm=0o2345, expected=0)

lines = ['.data\n.globl cases_v1563\n.globl case_count_v1563\n',
         '.equ case_count_v1563,0%o\n' % len(cases),
         'cases_v1563:\n']
for label, values in cases:
    lines.append('        ; %s\n' % label)
    lines.extend('        .word %s\n' %
                 ('-1' if value == -1 else '0%012o' % value)
                 for value in values)
(work / 'cases-v1563.s').write_text(''.join(lines))
(work / 'source-v1563.s').write_text(source)
mutants = (
    ('skip-staging-mount-owner',
     'caie    3,0100000              ; PROC_SIDL',
     'caie    3,0200000              ; wrong state'),
    ('ignore-staging-mount-high-bit',
     'andi    4,1                     ; SIDL RH fifth mount-slot bit',
     'setz    4,                      ; lost staged bit'),
    ('skip-staging-backing-owner',
     'caie    2,0100000              ; PROC_SIDL',
     'caie    2,0200000              ; wrong state'),
    ('ignore-staging-backing-high-bit',
     'hrrz    3,2(13)\n        andi    3,1',
     'hrrz    3,2(13)\n        setz    3,'),
    ('ignore-mount-pure-text',
     'jumpe   3,proc_swap_mount_busy_next',
     'jumpn   3,proc_swap_mount_busy_next'),
    ('ignore-swapped-saved-backing',
     'jumpe   3,proc_swap_mount_saved_v961',
     'jumpn   3,proc_swap_mount_saved_v961'),
)
for label, old, new in mutants:
    assert source.count(old) == 1, (label, source.count(old))
    (work / ('mutant-' + label + '-v1563.s')).write_text(
        source.replace(old, new, 1))
print('v1563: %d native PURE cases, %d unsafe mutations' %
      (len(cases), len(mutants)))
PY

run_case() {
    label=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 380000 --timeout 18 \
        --workdir "$work/run-$label" --name "dtfs-pure-$label-v1563" \
        --expect '__test_exit=0' \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-pure-staging-v1563.s" \
        "$work/cases-v1563.s" "$source" > "$work/$label.log" 2>&1
}
if ! run_case baseline "$work/source-v1563.s"; then
    tail -75 "$work/baseline.log" >&2
    echo 'FAIL v1563: actual PURE staging owner scanner' >&2
    exit 1
fi
echo 'PASS v1563: native resident, SIDL, swapped PURE guards'
for mutant in skip-staging-mount-owner ignore-staging-mount-high-bit \
    skip-staging-backing-owner ignore-staging-backing-high-bit \
    ignore-mount-pure-text ignore-swapped-saved-backing; do
    if run_case "$mutant" "$work/mutant-$mutant-v1563.s"; then
        echo "FAIL v1563: accepted unsafe mutation: $mutant" >&2
        exit 1
    fi
    grep -q 'FAIL: __test_exit:' "$work/$mutant.log" || {
        tail -30 "$work/$mutant.log" >&2
        echo "FAIL v1563: $mutant failed outside native oracle" >&2
        exit 1
    }
    echo "PASS v1563: rejected $mutant"
done
echo 'PASS v1563: production process PURE backing ownership'
