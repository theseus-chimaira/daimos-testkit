#!/bin/sh
# Source-matched original PDP-6 PURE RUN vs V2 quiescence, with mutants.
set -eu
: "${DAIMOS_REPO:?production DAIMOS source required}"
: "${PURE_QUIESCE_RUN_BUILD_V1646:?disposable 48K build required}"
: "${PURE_QUIESCE_RUN_TRACE_V1646:?physical simulator trace required}"
: "${PURE_QUIESCE_SOURCE_V1646:?source-derived original guest path required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-quiesce-run-audit-v1646.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
build=$PURE_QUIESCE_RUN_BUILD_V1646
python3 "$here/check-v2-v1647.py" \
    "$build/media/dtc3-home-v22.tap"
python3 "$here/test-v2-v1647.py" \
    "$build/media/dtc3-home-v22.tap"

# The only admitted difference from the exact compiled production VFS
# is the accepted v1565-style real scheduler interval.  Verify whole
# assembler source, rather than trusting a symbol name or build label.
python3 - "$DAIMOS_REPO/system/kernel/fs/vfs.s" \
    "$build/kcore-asm/vfs.s" "$DAIMOS_REPO/system/kernel/proc/proc_pure_attach.c" <<'PY'
from pathlib import Path
import sys

original = Path(sys.argv[1]).read_text(encoding="ascii")
compiled = Path(sys.argv[2]).read_text(encoding="ascii")
old = ("        movem   1,-2(17)               ; 1 for V2, zero otherwise\n"
       "        move    1,-1(17)\n"
       "        pushj   17,vfs_sync\n")
assert original.count(old) == 1
new = (
    "        movem   1,-2(17)               ; 1 for V2, zero otherwise\n"
    "        ; v1646 TEST ONLY: real 60Hz scheduler sleep AFTER the\n"
    "        ; actual V2 owner-quiescence bit is acquired. Never edit\n"
    "        ; original VFS owner/admission or unmount transaction.\n"
    "        .globl vfs_quiesce_sleep_done_v1646\n"
    "        skipn   -2(17)\n"
    "        jrst    vfs_quiesce_sleep_done_v1646\n"
    "        movei   1,01400               ; 768 real PI6 clock ticks\n"
    "        pushj   17,proc_sleep_ticks\n"
    "vfs_quiesce_sleep_done_v1646:\n"
    "        move    1,-1(17)\n"
    "        pushj   17,vfs_sync\n")
assert compiled == ".globl proc_sleep_ticks\n" + original.replace(old, new, 1)
assert "vfs_dtfs_owner_admit_v1562:" in original
assert "vfs_dtfs_quiesce_begin_v1562:" in original
assert "vfs_unmount_owner_check_v1523:" in original
proc = Path(sys.argv[3]).read_text(encoding="ascii")
assert proc.count("vfs_dtfs_owner_admit_v1562(backing) != 0") == 1
assert "proc_swap_records[slot].state = packed;" in proc
print("v1646: complete copied VFS equals production plus ONE real sleep")
PY

plain="$build/../user/init.dxr"
comp="$build/../user/comp-v1638.dxr"
python3 "$here/audit-v1646.py" "$build/kcore.map" "$plain" "$comp" \
    "$PURE_QUIESCE_RUN_TRACE_V1646" "$PURE_QUIESCE_SOURCE_V1646" \
    "$here/../pure-brk-pressure-v1614/test-v1614.c"

python3 - "$build/kcore.map" "$PURE_QUIESCE_RUN_TRACE_V1646" \
    "$work/fake-clock" "$work/fake-backing" "$work/fake-ro" <<'PY'
from pathlib import Path
import re
import sys

sym = {}
for line in Path(sys.argv[1]).read_text(encoding="ascii").splitlines():
    fields = line.split()
    if len(fields) >= 2 and re.fullmatch(r"[0-7]+", fields[1]):
        sym[fields[0]] = int(fields[1], 8)
trace = Path(sys.argv[2]).read_text(encoding="ascii")


def sample(name):
    first, last = "V1646_STAGE_%s\n" % name, "V1646_END_%s\n" % name
    assert trace.count(first) == trace.count(last) == 1
    head, rest = trace.split(first, 1)
    body, foot = rest.split(last, 1)
    words = {int(a, 8): int(v, 8) for a, v in re.findall(
        r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$", body)}
    return head, first, body, last, foot, words


def mutate(name, addr, value, dst):
    head, first, body, last, foot, words = sample(name)
    before = "%o:\t%012o" % (addr, words[addr])
    after = "%o:\t%012o" % (addr, value)
    assert body.count(before) == 1 and before != after
    Path(dst).write_text(head + first + body.replace(before, after, 1)
                         + last + foot, encoding="ascii")


start = sample("RACE_START")[5]
done = sample("UNMOUNT_DONE")[5]
clk = sym["clk_tick_count"]
assert done[clk] > start[clk]
mutate("UNMOUNT_DONE", clk, start[clk], sys.argv[3])
state = sym["proc_swap_records"] + 6
original = sample("RUN_REFUSED")[5][state]
mutate("RUN_REFUSED", state, original ^ 0o1000000, sys.argv[4])
policy = sym["vfs_mount_policy"]
q = sample("BARRIER")[5][policy]
assert not q & 0o2
mutate("BARRIER", policy, q | 0o2, sys.argv[5])
PY

for mutant in fake-clock fake-backing fake-ro; do
    if python3 "$here/audit-v1646.py" "$build/kcore.map" \
        "$plain" "$comp" "$work/$mutant" \
        "$PURE_QUIESCE_SOURCE_V1646" \
        "$here/../pure-brk-pressure-v1614/test-v1614.c" \
        >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1646: $mutant forged witness accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1646 physical quiescence RUN:' "$work/$mutant.log"
done
echo 'PASS v1646: forged quiescence clock, PURE backing record and RO gate rejected'
