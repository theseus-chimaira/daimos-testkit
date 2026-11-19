#!/bin/sh
# Require physical 48K six-child admission, accurate MM ownership,
# and the real parent's six WAIT statuses. Reject changed witnesses.
set -eu
: "${PURE_CACHE_LOW_BUILD_V1636:?source-built 48K image required}"
: "${PURE_CACHE_LOW_TRACE_V1636:?original B/A/Z physical trace required}"
: "${DAIMOS_REPO:?matching source for BCACHE code required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-cache-low-audit-v1636.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
map="$PURE_CACHE_LOW_BUILD_V1636/kcore.map"
guest="$PURE_CACHE_LOW_BUILD_V1636/../user/init-v1614.c"
cache="$DAIMOS_REPO/system/kernel/storage/bcache_pdp6.s"
dxr="$PURE_CACHE_LOW_BUILD_V1636/../user/dxrcheck.log"
python3 "$here/audit-v1636.py" "$map" "$PURE_CACHE_LOW_TRACE_V1636" \
    "$guest" "$cache" "$dxr"
python3 - "$map" "$PURE_CACHE_LOW_TRACE_V1636" \
    "$work/parent-forged" "$work/wait-forged" <<'PY'
from pathlib import Path
import re
import sys

sym = {f[0]: int(f[1], 8) for line in Path(sys.argv[1]).read_text(
    encoding="ascii").splitlines() if len(f := line.split()) >= 2
    and re.fullmatch(r"[0-7]+", f[1])}
source = Path(sys.argv[2]).read_text(encoding="ascii")
first, last = "V1636_STAGE_B\n", "V1636_END_B\n"
assert source.count(first) == source.count(last) == 1
pre, rest = source.split(first, 1)
section, post = rest.split(last, 1)
words = {int(a, 8): int(b, 8) for a, b in re.findall(
    r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", section)}
count = words[sym["mm_extent_count"]]
parent = []
for i in range(count):
    addr = sym["mm_extents"] + i * 2
    span, meta = words[addr], words[addr + 1]
    if (meta & 0o777777) == 1 and ((meta >> 18) & 7) == 1:
        parent.append((addr, span))
assert len(parent) == 1
address, span = parent[0]
assert (span & 0o777777) == 0o130000 and (span >> 18) == 0o10000
original = "%o:\t%012o" % (address, span)
forged = "%o:\t%012o" % (address, (0o10000 << 18) | 0o126000)
assert section.count(original) == 1
Path(sys.argv[3]).write_text(pre + first + section.replace(
    original, forged, 1) + last + post, encoding="ascii")
target = "LwwwwwwZV1636_STAGE_Z"
assert source.count(target) == 1
Path(sys.argv[4]).write_text(source.replace(
    target, "LwwwwwwYV1636_STAGE_Z", 1), encoding="ascii")
PY
for mutant in parent-forged wait-forged; do
    if python3 "$here/audit-v1636.py" "$map" "$work/$mutant" \
        "$guest" "$cache" "$dxr" >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1636: accepted forged $mutant original MM evidence" >&2
        exit 1
    fi
    grep -q '^FAIL v1636 physical cache/MM audit:' \
        "$work/$mutant.log"
done
echo 'PASS v1636: displaced-parent and missing-WAIT evidence rejected'
