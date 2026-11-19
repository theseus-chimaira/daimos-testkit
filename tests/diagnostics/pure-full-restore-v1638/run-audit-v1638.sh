#!/bin/sh
# Audit original physical bounded FULL call with both simultaneous MM
# owners, actual compressed PURE source, and all six final WAIT results.
set -eu
: "${PURE_FULL_BUILD_V1638:?source-built mixed-PURE guest required}"
: "${PURE_FULL_TRACE_V1638:?original physical B/A/FULL/Z trace required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-full-audit-v1638.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
build="$PURE_FULL_BUILD_V1638"
"$PDP10_PREFIX/bin/dxrcheck" -d "$build/pure-mres-v1612.dxr" \
    >"$work/mres-dxrcheck-v1638.txt"
set -- "$build/kcore.map" "$build/pure-mres-v1612.map" \
    "$work/mres-dxrcheck-v1638.txt" "$PURE_FULL_TRACE_V1638" \
    "$build/../user/init-v1614.c" "$build/../user/init.dxr" \
    "$build/../user/comp-v1638.dxr" \
    "$build/../tsfs-root-v1638.manifest"
python3 "$here/audit-v1638.py" "$@"
python3 - "$1" "$PURE_FULL_TRACE_V1638" \
    "$work/foreign-target-v1638" "$work/false-wait-v1638" <<'PY'
from pathlib import Path
import re
import sys

symbols = {}
for line in Path(sys.argv[1]).read_text(encoding="ascii").splitlines():
    f = line.split()
    if len(f) >= 2 and re.fullmatch(r"[0-7]+", f[1]):
        symbols[f[0]] = int(f[1], 8)
trace = Path(sys.argv[2]).read_text(encoding="ascii")
part = trace.split("V1638_BOUNDED_FULL\n", 1)[1].split(
    "V1638_STAGE_FULL\n", 1)[0]
acs = {int(a, 8): int(b, 8) for a, b in re.findall(
    r"(?m)^\s*([1-4]):\s*([0-7]{1,12})\s*$", part)}
target = acs[2]
first, last = "V1638_STAGE_FULL\n", "V1638_END_FULL\n"
assert trace.count(first) == trace.count(last) == 1
before, tail = trace.split(first, 1)
section, after = tail.split(last, 1)
words = {int(a, 8): int(b, 8) for a, b in re.findall(
    r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", section)}
found = []
for i in range(words[symbols["mm_extent_count"]]):
    addr = symbols["mm_extents"] + i * 2
    span, meta = words[addr], words[addr + 1]
    if (span & 0o777777) == target and ((meta >> 18) & 7) == 1:
        found.append((addr + 1, meta))
assert len(found) == 1
address, meta = found[0]
old = "%o:\t%012o" % (address, meta)
new = "%o:\t%012o" % (address, (meta & ~0o777777) | 0o40)
assert section.count(old) == 1
Path(sys.argv[3]).write_text(before + first + section.replace(
    old, new, 1) + last + after, encoding="ascii")
assert trace.count("ZV1638_STAGE_Z") == 1
Path(sys.argv[4]).write_text(trace.replace(
    "ZV1638_STAGE_Z", "YV1638_STAGE_Z", 1), encoding="ascii")
PY
for mutant in foreign-target-v1638 false-wait-v1638; do
    if python3 "$here/audit-v1638.py" \
        "$build/kcore.map" "$build/pure-mres-v1612.map" \
        "$work/mres-dxrcheck-v1638.txt" "$work/$mutant" \
        "$build/../user/init-v1614.c" "$build/../user/init.dxr" \
        "$build/../user/comp-v1638.dxr" \
        "$build/../tsfs-root-v1638.manifest" \
        >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1638: accepted forged $mutant machine evidence" >&2
        exit 1
    fi
    grep -q '^FAIL v1638 physical FULL restore audit:' \
        "$work/$mutant.log"
done
echo 'PASS v1638: foreign FULL target owner and false parent WAIT rejected'
