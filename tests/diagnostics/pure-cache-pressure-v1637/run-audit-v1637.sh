#!/bin/sh
# Reject forged source-linked PACKED owners and false child WAIT success.
set -eu
: "${PURE_CACHE_PRESSURE_BUILD_V1637:?original pressure build required}"
: "${PURE_CACHE_PRESSURE_TRACE_V1637:?original physical B/A/Z trace required}"
: "${DAIMOS_REPO:?matching source required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-cache-pressure-audit-v1637.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
map="$PURE_CACHE_PRESSURE_BUILD_V1637/kcore.map"
guest="$PURE_CACHE_PRESSURE_BUILD_V1637/../user/init-v1614.c"
cache="$DAIMOS_REPO/system/kernel/storage/bcache_pdp6.s"
dxr="$PURE_CACHE_PRESSURE_BUILD_V1637/../user/dxrcheck.log"
python3 "$here/audit-v1637.py" "$map" "$PURE_CACHE_PRESSURE_TRACE_V1637" \
    "$guest" "$cache" "$dxr"
python3 - "$map" "$PURE_CACHE_PRESSURE_TRACE_V1637" \
    "$work/owner-mutant" "$work/wait-mutant" <<'PY'
from pathlib import Path
import re
import sys

syms = {f[0]: int(f[1], 8) for line in Path(sys.argv[1]).read_text(
    encoding="ascii").splitlines() if len(f := line.split()) >= 2
    and re.fullmatch(r"[0-7]+", f[1])}
source = Path(sys.argv[2]).read_text(encoding="ascii")
first, last = "V1637_STAGE_B\n", "V1637_END_B\n"
assert source.count(first) == source.count(last) == 1
pre, rest = source.split(first, 1)
section, post = rest.split(last, 1)
words = {int(a, 8): int(v, 8) for a, v in re.findall(
    r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", section)}
packed = []
for i in range(words[syms["mm_extent_count"]]):
    address = syms["mm_extents"] + 2 * i + 1
    meta = words[address]
    if ((meta >> 18) & 7) == 4:
        packed.append((address, meta))
assert packed, "original guest has no PACKED owner to mutate"
address, meta = packed[0]
old = "%o:\t%012o" % (address, meta)
new = "%o:\t%012o" % (address, (meta & ~0o777777) | 0o40)
assert section.count(old) == 1
Path(sys.argv[3]).write_text(pre + first + section.replace(
    old, new, 1) + last + post, encoding="ascii")
target = "LwwwwwwZV1637_STAGE_Z"
assert source.count(target) == 1
Path(sys.argv[4]).write_text(source.replace(
    target, "LwwwwwwYV1637_STAGE_Z", 1), encoding="ascii")
PY
for mutant in owner-mutant wait-mutant; do
    if python3 "$here/audit-v1637.py" "$map" "$work/$mutant" \
        "$guest" "$cache" "$dxr" >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1637: accepted forged $mutant physical evidence" >&2
        exit 1
    fi
    grep -q '^FAIL v1637 physical PACKED pressure:' \
        "$work/$mutant.log"
done
echo 'PASS v1637: false PACKED owner and parent WAIT rejected'
