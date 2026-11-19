#!/bin/sh
# Source-linked physical MM/ABI ownership and negative controls v1644.
set -eu
: "${DAIMOS_REPO:?matching DAIMOS source required}"
: "${PURE_BACKING_GUARDS_BUILD_V1644:?source-built RW guest required}"
: "${PURE_BACKING_GUARDS_TRACE_V1644:?complete physical replay required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-backing-guards-audit-v1644.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
build="$PURE_BACKING_GUARDS_BUILD_V1644"
python3 - "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
proc = (root / "system/kernel/proc/proc_pure_backing_pdp6.s").read_text()
vfs = (root / "system/kernel/fs/vfs.s").read_text()
files = (root / "system/kernel/fs/file_runtime.s").read_text()
dtfs = (root / "system/kernel/fs/dtfs_runtime.s").read_text()
for phrase in ("proc_swap_backing_busy:", "proc_swap_mount_busy:"):
    assert phrase in proc
for phrase in ("vfs_write_guard_v449:",
               "pushj   17,proc_swap_backing_busy",
               "vfs_unmount_owner_check_v1523:",
               "pushj   17,proc_swap_mount_busy"):
    assert phrase in vfs
assert "pushj   17,proc_swap_backing_busy" in files
assert "dtfs_rename_native:\n" in dtfs
assert "pushj   17,dtfs_set_name" in dtfs
PY
python3 "$here/audit-v1644.py" "$build/kcore.map" \
    "$build/../user/init.dxr" "$build/../user/comp-v1638.dxr" \
    "$PURE_BACKING_GUARDS_TRACE_V1644" \
    "$build/../user/init-v1614.c"

python3 - "$build/kcore.map" "$PURE_BACKING_GUARDS_TRACE_V1644" \
    "$work/fake-ro" "$work/retained-pin" "$work/wrong-mount" <<'PY'
from pathlib import Path
import re
import sys

symbols = {}
for line in Path(sys.argv[1]).read_text(encoding="ascii").splitlines():
    fields = line.split()
    if len(fields) >= 2 and re.fullmatch(r"[0-7]+", fields[1]):
        symbols[fields[0]] = int(fields[1], 8)
trace = Path(sys.argv[2]).read_text(encoding="ascii")
start, end = "V1644_STAGE_PROTECTED\n", "V1644_END_PROTECTED\n"
assert trace.count(start) == trace.count(end) == 1
head, remain = trace.split(start, 1)
part, tail = remain.split(end, 1)
words = {int(a, 8): int(v, 8) for a, v in re.findall(
    r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$", part)}

# Forged read-only mode: successful mutation refusal no longer proves
# a genuine PURE busy guard and must NEVER be accepted as this gate.
addr = symbols["vfs_mount_policy"]
value = words[addr]
assert not value & 0o2
old = "%o:\t%012o" % (addr, value)
new = "%o:\t%012o" % (addr, value | 0o2)
assert part.count(old) == 1
Path(sys.argv[3]).write_text(head + start + part.replace(old, new, 1)
                              + end + tail, encoding="ascii")

# Forged retained physical owner pin after all guards, violating
# the unchanged six-PACKED suffix and no-leak requirement.
found = []
for i in range(words[symbols["mm_extent_count"]]):
    addr = symbols["mm_extents"] + 2 * i + 1
    val = words[addr]
    if (val & 0o777777) == 3 and ((val >> 18) & 7) == 4:
        found.append((addr, val))
assert len(found) == 1
addr, value = found[0]
assert (value >> 21) & 255 == 0
old = "%o:\t%012o" % (addr, value)
new = "%o:\t%012o" % (addr, value | 0o10000000)
assert part.count(old) == 1
Path(sys.argv[4]).write_text(head + start + part.replace(old, new, 1)
                              + end + tail, encoding="ascii")

# A nonsecondary mount is not a proof of secondary protection.
start, end = "V1644_MOUNT_GUARD_ENTRY\n", "V1644_STAGE_MOUNT_BUSY\n"
assert trace.count(start) == trace.count(end) == 1
head, remain = trace.split(start, 1)
part, tail = remain.split(end, 1)
assert re.search(r"(?m)^1:\s*0*2\s*$", part)
part = re.sub(r"(?m)^(1:\s*)000000000002(\s*)$",
              r"\g<1>000000000003\g<2>", part, count=1)
Path(sys.argv[5]).write_text(head + start + part + end + tail,
                              encoding="ascii")
PY

for mutant in fake-ro retained-pin wrong-mount; do
    if python3 "$here/audit-v1644.py" "$build/kcore.map" \
        "$build/../user/init.dxr" "$build/../user/comp-v1638.dxr" \
        "$work/$mutant" "$build/../user/init-v1614.c" \
        >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1644: $mutant forged physical witness accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1644 immutable source physical audit:' \
        "$work/$mutant.log"
done
echo 'PASS v1644: false RO policy, retained RAW pin, wrong mount rejected'
