#!/bin/sh
# Native PDP-6 production scheduler/service selection and retry epoch gate.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-backstore-retry-v1507.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1507 work: $work"; fi' EXIT HUP INT TERM

# Reuse the source-authentic checked-free transaction/slot-0 fixture.
KEEP_TEST=1 sh "$self/daimos-swap-checked-scheduler-v1493.sh" > "$work/prereq.log"
cat "$work/prereq.log"
base=$(sed -n 's/^v1493 work: //p' "$work/prereq.log" | tail -1)
test -n "$base" && test -f "$base/production-v1493.s"
python3 - "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" "$base" "$work" <<'PY'
from pathlib import Path
import re
import sys

sched = Path(sys.argv[1]).read_text()
base = Path(sys.argv[2])
work = Path(sys.argv[3])
swap = (base / "production-v1493.s").read_text()
fixture = (base / "fixture-v1493.s").read_text()

def leaf(text, first, last):
    assert text.count(first) == 1, "ambiguous production entry: " + first
    tail = text.split(first, 1)[1]
    assert last in tail, "missing production end: " + first
    return first + tail.split(last, 1)[0]

existing = set(re.findall(r'(?m)^\s*\.equ\s+(\w+)\s*,', swap))
equates = []
for line in sched.splitlines():
    match = re.match(r'\s*\.equ\s+(\w+)\s*,', line)
    if match and match.group(1) not in existing:
        equates.append(line)
        existing.add(match.group(1))

selection = leaf(sched, "proc_select_runnable_pdp6:\n",
                 "\n/**\n * @brief Reparent children")
clock = leaf(sched, "proc_sched_pi_tick:\n",
             "\nproc_sched_timer_done:\n")
clock += "\nproc_sched_timer_done:\n        popj    17,\n"
production = "\n".join((swap, "\n".join(equates), ".globl proc_select_runnable_pdp6",
                        ".globl proc_sched_pi_tick", selection, clock))
(work / "production-v1507.s").write_text(production)

# Two additional real scheduler descriptors (one resident, one swapped).
# The v1493 fixture owns slot 2; extend its single static test table only.
old = "__record: .word 0\n        .word 0\n        .word 1,,010\n"
assert fixture.count(old) == 1
fixture = fixture.replace(old, old + "        .word 03,,010\n", 1)
old = "        .word 0200000000000\n__mode_v1405:"
assert fixture.count(old) == 1
fixture = fixture.replace(old, "        .word 0200000000000\n        .block 3\n__mode_v1405:", 1)
# The driver is appended by the shell to keep the assembler fixture in
# the same unit as its private labels.
(work / "fixture-v1507.s").write_text(fixture)
PY
cat "$self/daimos-backstore-retry-scheduler-v1507.s" \
    > "$work/driver-v1507.s"
python3 - "$self/daimos-swap-checked-scheduler-v1493.s" \
    "$work/stubs-v1507.s" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
start = "        .globl proc_event_apply\n"
end = "        .data\n"
assert source.count(start) == 1 and source.count(end) == 1
Path(sys.argv[2]).write_text(".text\n" + start +
    source.split(start, 1)[1].split(end, 1)[0])
PY
cat "$work/stubs-v1507.s" "$work/fixture-v1507.s" \
    >> "$work/driver-v1507.s"

run() {
    name=$1
    production=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 800000 --timeout 35 \
        --workdir "$work/$name" --name "$name" \
        --expect __test_exit=0 --expect event_calls_v1493=3 \
        --examine stage_v1507 \
        --expect __publish_calls_v1405=1 \
        --expect __rollback_calls_v1405=1 \
        --expect __invariant_calls_v1405=0 \
        --expect __store_bad_v1405=0 \
        "$self/daimos-test-crt0-v1.s" "$production" \
        "$work/driver-v1507.s" > "$work/$name.log" 2>&1
}
if ! run passing "$work/production-v1507.s"; then
    tail -85 "$work/passing.log" >&2
    exit 1
fi
echo 'PASS v1507: real checked BACKSTORE refusal records per-owner retry'
echo 'PASS v1507: healthy swapped job eligible; two failed owners do not livelock'
echo 'PASS v1507: realtime owner deferred; 64-tick epoch and repair restore'
echo 'PASS v1507: stale marker retired; independent retries span clock wrap'

# Each mutation must be caught by the native assertions, not a build error.
python3 - "$work" <<'PY'
from pathlib import Path
import sys

work = Path(sys.argv[1])
source = (work / "production-v1507.s").read_text()
changes = {
    "no-stamp": (
        "        movem   3,PROC_FINALIZE_OFFSET(4)\n",
        "        setzm   PROC_FINALIZE_OFFSET(4)\n"),
    "no-normal-gate": (
        "        caige   3,PROC_SWAP_RETRY_TICKS\n"
        "        jrst    proc_select_next\n",
        "        jrst    proc_select_score\n"
        "        jrst    proc_select_next\n"),
    "no-rt-gate": (
        "        jrst    proc_select_rt_retry_v1507\n",
        "        jrst    proc_select_rt_swap\n"),
}
for name, (old, new) in changes.items():
    assert source.count(old) == 1, "missing mutation target: " + name
    (work / (name + ".s")).write_text(source.replace(old, new, 1))
PY
for mutant in no-stamp no-normal-gate no-rt-gate; do
    if run "$mutant" "$work/$mutant.s"; then
        echo "FAIL v1507: $mutant mutation survived" >&2
        exit 1
    fi
    if ! grep -q '^FAIL: __test_exit:' "$work/$mutant.log"; then
        echo "FAIL v1507: $mutant was not rejected by driver assertions" >&2
        tail -45 "$work/$mutant.log" >&2
        exit 1
    fi
    echo "PASS v1507: $mutant mutation rejected"
done
rm -rf "$base"
