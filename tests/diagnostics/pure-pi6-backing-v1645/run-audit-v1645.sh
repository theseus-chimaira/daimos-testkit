#!/bin/sh
# Original physical 48K PI6 clock and executable-backing lifetime auditor.
set -eu
: "${DAIMOS_REPO:?matching original DAIMOS source required}"
: "${PURE_PI6_BACKING_BUILD_V1645:?source-built 48K v1645 guest required}"
: "${PURE_PI6_BACKING_TRACE_V1645:?original physical simulator trace required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-pi6-backing-audit-v1645.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
build="$PURE_PI6_BACKING_BUILD_V1645"

# The original PI6 scheduler must not replace an ordinary in-flight RUN
# executive continuation. An explicitly SLEEPing syscall can switch,
# and the 60Hz hardware-clock path advances the original epoch/CLK.
# This checks the source contract; the physical audit below checks
# genuinely observed time and MM, not guessed simulator timing.
python3 - "$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s" \
    "$DAIMOS_REPO/system/kernel/drivers/clk_io.s" <<'PY'
from pathlib import Path
import sys

proc = Path(sys.argv[1]).read_text(encoding="ascii")
clk = Path(sys.argv[2]).read_text(encoding="ascii")
tick = proc.split('proc_sched_pi_tick:\n', 1)[1].split(
    'proc_sched_select:\n', 1)[0]
for token in ('aos     1,proc_timer_clock',
              'proc_sched_exec_tick:',
              'caie    2,PROC_STATE_RUN',
              'jrst    proc_sched_exec_switch',
              'proc_sched_exec_switch:',
              'pushj   17,proc_save_kernel'):
    assert token in tick, token
assert 'popj    17,' in tick.split('proc_sched_exec_tick:\n', 1)[1].split(
    'proc_sched_exec_switch:\n', 1)[0]
resched = proc.split('proc_sched_pi_resched:\n', 1)[1].split(
    'proc_sched_pi_tick:\n', 1)[0]
assert 'proc_save_kernel' in resched
assert 'proc_sched_resched_select' in resched
assert 'clk_pi_tick:\n        aos clk_tick_count' in clk
assert 'pushj 017,proc_sched_pi_tick' in clk
print('v1645: source PI6 executive RUN/no-switch and real CLK path PASS')
PY

python3 "$here/audit-v1645.py" "$build/kcore.map" \
    "$build/../user/init.dxr" "$build/../user/comp-v1638.dxr" \
    "$PURE_PI6_BACKING_TRACE_V1645" "$build/../user/init-v1614.c"

python3 - "$build/kcore.map" "$PURE_PI6_BACKING_TRACE_V1645" \
    "$work/frozen-clock" "$work/false-owner-pin" "$work/ro-source" <<'PY'
from pathlib import Path
import re
import sys

symbols = {}
for line in Path(sys.argv[1]).read_text(encoding="ascii").splitlines():
    fields = line.split()
    if len(fields) >= 2 and re.fullmatch(r"[0-7]+", fields[1]):
        symbols[fields[0]] = int(fields[1], 8)
trace = Path(sys.argv[2]).read_text(encoding="ascii")


def stage(name):
    head = "V1645_STAGE_%s\n" % name
    tail = "V1645_END_%s\n" % name
    assert trace.count(head) == trace.count(tail) == 1
    before, rest = trace.split(head, 1)
    segment, after = rest.split(tail, 1)
    words = {int(a, 8): int(b, 8) for a, b in re.findall(
        r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$",
        segment)}
    return before, head, segment, tail, after, words


def changed(name, addr, value, output):
    before, head, segment, tail, after, words = stage(name)
    old = "%o:\t%012o" % (addr, words[addr])
    new = "%o:\t%012o" % (addr, value)
    assert segment.count(old) == 1 and old != new
    Path(output).write_text(before + head + segment.replace(old, new, 1)
                            + tail + after, encoding="ascii")


prior = stage('WAKE_SENT')[5]
tick = symbols['clk_tick_count']
now = stage('PI6_WINDOW')[5]
assert now[tick] > prior[tick]
changed('PI6_WINDOW', tick, prior[tick], sys.argv[3])

raw = stage('PI6_GUARD')[5]
source = None
for i in range(raw[symbols['mm_extent_count']]):
    addr = symbols['mm_extents'] + 2 * i + 1
    meta = raw[addr]
    if (meta & 0o777777) == 3 and (meta >> 18) & 7 == 4:
        source = (addr, meta)
        break
if source is None:
    for i in range(raw[symbols['mm_extent_count']]):
        addr = symbols['mm_extents'] + 2 * i + 1
        meta = raw[addr]
        if 2 <= (meta & 0o777777) <= 7 and (meta >> 18) & 7 == 4:
            source = (addr, meta)
            break
assert source is not None
addr, meta = source
changed('PI6_GUARD', addr, (meta & ~(0o377 << 21)) | (2 << 21),
        sys.argv[4])

addr = symbols['vfs_mount_policy']
policy = raw[addr]
assert (policy & 2) == 0
changed('PI6_GUARD', addr, policy | 2, sys.argv[5])
PY

for mutant in frozen-clock false-owner-pin ro-source; do
    if python3 "$here/audit-v1645.py" "$build/kcore.map" \
        "$build/../user/init.dxr" "$build/../user/comp-v1638.dxr" \
        "$work/$mutant" "$build/../user/init-v1614.c" \
        >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1645: accepted falsified $mutant" >&2
        exit 1
    fi
    grep -q '^FAIL v1645 PI6 backing lifetime:' "$work/$mutant.log"
done
echo 'PASS v1645: false PI6 clock, source pin and RO-policy rejected'
