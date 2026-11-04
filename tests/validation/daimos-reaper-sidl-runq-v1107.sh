#!/bin/sh
# v1107: only SIDL owns sched RH bit 02 as a discard-VM marker.
# A live EXIT can have a runq successor whose slot number contains bit 02.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-reaper-sidl-runq-v1107.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" "$work" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
work = Path(sys.argv[2])
start = 'proc_finish_service_v881:'
end = '/**\n * @brief Discard an uncommitted RUN slot'
assert source.count(start) == 1 and source.count(end) == 1
leaf = start + source.split(start, 1)[1].split(end, 1)[0]
header = ('.text\n'
          '.equ PROC_WORDS,3\n'
          '.equ PROC_TRANSITION_RH,0200000\n'
          '.equ PROC_STATE_LH_MASK,0700000\n'
          '.equ PROC_FINALIZE_OFFSET,067\n'
          '.equ PROC_FINALIZE_MARK_LH,0400000\n'
          '.equ PROC_FINALIZE_PREVM_LH,0100000\n'
          '.globl proc_finish_service_v881\n')
good = ('''        move    4,2(2)
        hlrz    5,4
        andi    5,PROC_STATE_LH_MASK
        caie    5,0100000             ; PROC_SIDL
        jrst    proc_finish_service_post_vm_v894
        trnn    4,02                   ; SIDL-only DISCARD_VM marker
        jrst    proc_finish_service_post_vm_v894''')
bad = ('''        move    4,2(2)
        trnn    4,02
        jrst    proc_finish_service_post_vm_v894
        hlrz    5,4
        andi    5,PROC_STATE_LH_MASK
        caie    5,0100000
        jrst    proc_finish_service_next_v881''')
assert leaf.count(good) == 1
(work / 'leaf.s').write_text(header + leaf)
(work / 'unsafe-runq-bit.s').write_text(
    header + leaf.replace(good, bad, 1))
PY

run_case() {
    name=$1
    leaf=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 50000 --timeout 20 \
        --workdir "$work/run-$name" --name "reaper-runq-v1107-$name" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" "$leaf" \
        "$self/daimos-reaper-sidl-runq-v1107.s" >"$work/log-$name" 2>&1
}
if ! run_case positive "$work/leaf.s"; then
    tail -60 "$work/log-positive" >&2
    exit 1
fi
if run_case unsafe "$work/unsafe-runq-bit.s"; then
    echo 'v1107: old runq/SIDL-bit collision erroneously passed' >&2
    exit 1
fi
echo 'v1107: live PREVM runq next=2 and SIDL discard distinct, old mutant rejected PASS'
