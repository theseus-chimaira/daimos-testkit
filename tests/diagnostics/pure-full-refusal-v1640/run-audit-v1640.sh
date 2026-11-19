#!/bin/sh
# Source-linked actual FULL MM NOMEM and unpin rollback.
# Reject a forged cleanup pin and a forged allocator return code.
set -eu
: "${PURE_FULL_REFUSAL_BUILD_V1640:?original 48K mixed build required}"
: "${PURE_FULL_REFUSAL_TRACE_V1640:?original simulator trace required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-full-refusal-audit-v1640.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
build="$PURE_FULL_REFUSAL_BUILD_V1640"
"$PDP10_PREFIX/bin/dxrcheck" -d "$build/pure-mres-v1612.dxr" \
    >"$work/mres.txt"
test $# -eq 0
python3 "$here/audit-v1640.py" "$build/kcore.map" \
    "$build/pure-mres-v1612.map" "$work/mres.txt" \
    "$PURE_FULL_REFUSAL_TRACE_V1640" \
    "$build/../user/init-v1614.c" "$build/../user/init.dxr" \
    "$build/../user/comp-v1638.dxr" \
    "$build/../tsfs-root-v1638.manifest"
python3 - "$build/kcore.map" "$PURE_FULL_REFUSAL_TRACE_V1640" \
    "$work/pin-mutant" "$work/return-mutant" <<'PY'
from pathlib import Path
import re
import sys

syms = {}
for line in Path(sys.argv[1]).read_text(encoding="ascii").splitlines():
    f = line.split()
    if len(f) >= 2 and re.fullmatch(r"[0-7]+", f[1]):
        syms[f[0]] = int(f[1], 8)
text = Path(sys.argv[2]).read_text(encoding="ascii")
start, end = "V1640_STAGE_ROLLED_BACK\n", "V1640_END_ROLLED_BACK\n"
assert text.count(start) == text.count(end) == 1
pre, rest = text.split(start, 1)
part, post = rest.split(end, 1)
data = {int(a, 8): int(v, 8) for a, v in re.findall(
    r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", part)}
found = []
for i in range(data[syms["mm_extent_count"]]):
    addr = syms["mm_extents"] + i * 2 + 1
    meta = data[addr]
    if ((meta >> 18) & 7) == 4 and (meta & 0o777777) == 2:
        found.append((addr, meta))
assert len(found) == 1
addr, meta = found[0]
old, new = ("%o:\t%012o" % (addr, val)
            for val in (meta, meta | 0o10000000))
assert part.count(old) == 1
Path(sys.argv[3]).write_text(pre + start + part.replace(old, new, 1)
                              + end + post, encoding="ascii")
first, last = "V1640_ALLOC_RETURN\n", "V1640_STAGE_PINNED_FAILURE\n"
assert text.count(first) == text.count(last) == 1
before, rest = text.split(first, 1)
segment, after = rest.split(last, 1)
assert re.search(r"(?m)^1:\s*777777777777\s*$", segment)
segment = re.sub(r"(?m)^(1:\s*)777777777777(\s*)$", r"\g<1>0\g<2>",
                 segment, count=1)
Path(sys.argv[4]).write_text(before + first + segment + last + after,
                              encoding="ascii")
PY
for mutant in pin-mutant return-mutant; do
    if python3 "$here/audit-v1640.py" "$build/kcore.map" \
        "$build/pure-mres-v1612.map" "$work/mres.txt" \
        "$work/$mutant" "$build/../user/init-v1614.c" \
        "$build/../user/init.dxr" "$build/../user/comp-v1638.dxr" \
        "$build/../tsfs-root-v1638.manifest" \
        >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1640: falsified $mutant accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1640 physical FULL refusal audit:' "$work/$mutant.log"
done
echo 'PASS v1640: forged source pin and false no-memory return rejected'
