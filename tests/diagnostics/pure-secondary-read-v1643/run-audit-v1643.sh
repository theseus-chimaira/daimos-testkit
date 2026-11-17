#!/bin/sh
# Source-linked original 48K physical secondary-DTFS PURE read failure.
# Reject fake post-failure pin retention and fake successful callback.
set -eu
: "${DAIMOS_REPO:?original DAIMOS source required}"
: "${PURE_SECONDARY_BUILD_V1643:?original secondary guest build required}"
: "${PURE_SECONDARY_TRACE_V1643:?original physical simulator trace required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-secondary-audit-v1643.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
build="$PURE_SECONDARY_BUILD_V1643"
"$PDP10_PREFIX/bin/dxrcheck" -d "$build/pure-mres-v1612.dxr" \
    >"$work/mres.txt"
python3 - "$DAIMOS_REPO/system/kernel/proc/vm_pdp6_pure_range_v1604.h" <<'PY'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text(encoding="ascii")
assert "skip = (text + EXEC_USER_ORIGIN) &" in text
assert "~(PDP6_PURE_SECTOR_V1604 - 1UL);" in text
assert "#define PDP6_PURE_SECTOR_V1604 0200UL" in text
PY
python3 "$here/audit-v1643.py" "$build/kcore.map" \
    "$build/pure-mres-v1612.map" "$work/mres.txt" \
    "$PURE_SECONDARY_TRACE_V1643" "$build/../user/init-v1614.c" \
    "$build/../user/init.dxr" "$build/../user/comp-v1638.dxr" \
    "$build/../tsfs-root-v1638.manifest"

python3 - "$build/kcore.map" "$PURE_SECONDARY_TRACE_V1643" \
    "$work/leaked-pin" "$work/fake-success" <<'PY'
from pathlib import Path
import re
import sys

symbols = {}
for line in Path(sys.argv[1]).read_text(encoding="ascii").splitlines():
    fields = line.split()
    if len(fields) >= 2 and re.fullmatch(r"[0-7]+", fields[1]):
        symbols[fields[0]] = int(fields[1], 8)
trace = Path(sys.argv[2]).read_text(encoding="ascii")
start = "V1643_STAGE_ROLLED_BACK\n"
end = "V1643_END_ROLLED_BACK\n"
assert trace.count(start) == trace.count(end) == 1
prefix, remains = trace.split(start, 1)
block, suffix = remains.split(end, 1)
words = {int(a, 8): int(v, 8) for a, v in re.findall(
    r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$", block)}
owners = []
for i in range(words[symbols["mm_extent_count"]]):
    addr = symbols["mm_extents"] + 2 * i + 1
    meta = words[addr]
    if (meta & 0o777777) == 3 and (meta >> 18) & 7 == 4:
        owners.append((addr, meta))
assert len(owners) == 1
addr, meta = owners[0]
assert ((meta >> 21) & 255) == 0
old = "%o:\t%012o" % (addr, meta)
new = "%o:\t%012o" % (addr, meta | 0o10000000)
assert block.count(old) == 1
Path(sys.argv[3]).write_text(prefix + start + block.replace(old, new, 1)
                              + end + suffix, encoding="ascii")

start = "V1643_FAILED_FULL_RETURN\n"
end = "V1643_STAGE_ROLLED_BACK\n"
assert trace.count(start) == trace.count(end) == 1
prefix, remains = trace.split(start, 1)
block, suffix = remains.split(end, 1)
assert re.search(r"(?m)^1:\s*777777777774\s*$", block)
block = re.sub(r"(?m)^(1:\s*)777777777774(\s*)$",
               r"\g<1>000000000000\g<2>", block, count=1)
Path(sys.argv[4]).write_text(prefix + start + block + end + suffix,
                              encoding="ascii")
PY
for mutant in leaked-pin fake-success; do
    if python3 "$here/audit-v1643.py" "$build/kcore.map" \
        "$build/pure-mres-v1612.map" "$work/mres.txt" \
        "$work/$mutant" "$build/../user/init-v1614.c" \
        "$build/../user/init.dxr" "$build/../user/comp-v1638.dxr" \
        "$build/../tsfs-root-v1638.manifest" \
        >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1643: forged $mutant accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1643 physical secondary FULL I/O:' \
        "$work/$mutant.log"
done
echo 'PASS v1643: forged retained source pin and fake successful I/O rejected'
