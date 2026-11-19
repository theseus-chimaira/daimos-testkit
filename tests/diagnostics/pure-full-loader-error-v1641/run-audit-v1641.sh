#!/bin/sh
# Physical MM rollback under a one-shot TEST-SIMULATED loader failure.
# Source, executable and MRES are original; only AC1 is injected once.
set -eu
: "${PURE_FULL_LOADER_BUILD_V1641:?original v1638 guest/build required}"
: "${PURE_FULL_LOADER_TRACE_V1641:?original v1641 simulator trace required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-full-loader-audit-v1641.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
build="$PURE_FULL_LOADER_BUILD_V1641"
"$PDP10_PREFIX/bin/dxrcheck" -d "$build/pure-mres-v1612.dxr" \
    >"$work/mres.txt"
python3 "$here/audit-v1641.py" "$build/kcore.map" \
    "$build/pure-mres-v1612.map" "$work/mres.txt" \
    "$PURE_FULL_LOADER_TRACE_V1641" \
    "$build/../user/init-v1614.c" "$build/../user/init.dxr" \
    "$build/../user/comp-v1638.dxr" \
    "$build/../tsfs-root-v1638.manifest"
python3 - "$build/kcore.map" "$PURE_FULL_LOADER_TRACE_V1641" \
    "$work/pinned-source" "$work/false-success" <<'PY'
from pathlib import Path
import re
import sys

syms = {}
for line in Path(sys.argv[1]).read_text(encoding="ascii").splitlines():
    f = line.split()
    if len(f) >= 2 and re.fullmatch(r"[0-7]+", f[1]):
        syms[f[0]] = int(f[1], 8)
text = Path(sys.argv[2]).read_text(encoding="ascii")
start, end = "V1641_STAGE_ROLLED_BACK\n", "V1641_END_ROLLED_BACK\n"
assert text.count(start) == text.count(end) == 1
pre, rem = text.split(start, 1)
part, post = rem.split(end, 1)
words = {int(a, 8): int(v, 8) for a, v in re.findall(
    r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", part)}
got = []
for i in range(words[syms["mm_extent_count"]]):
    addr = syms["mm_extents"] + i * 2 + 1
    meta = words[addr]
    if ((meta >> 18) & 7) == 4 and (meta & 0o777777) == 3:
        got.append((addr, meta))
assert len(got) == 1
addr, meta = got[0]
old = "%o:\t%012o" % (addr, meta)
new = "%o:\t%012o" % (addr, meta | 0o10000000)
assert part.count(old) == 1
Path(sys.argv[3]).write_text(pre + start + part.replace(old, new, 1)
                              + end + post, encoding="ascii")
first, last = "V1641_LOADER_RETURN_OK\n", "V1641_STAGE_PINNED_BEFORE_ERROR\n"
assert text.count(first) == text.count(last) == 1
pre, rem = text.split(first, 1)
part, post = rem.split(last, 1)
assert re.search(r"(?m)^1:\s*0+\s*$", part)
part = re.sub(r"(?m)^(1:\s*)0+(\s*)$", r"\g<1>777777777777\g<2>",
              part, count=1)
Path(sys.argv[4]).write_text(pre + first + part + last + post,
                              encoding="ascii")
PY
for mutant in pinned-source false-success; do
    if python3 "$here/audit-v1641.py" "$build/kcore.map" \
        "$build/pure-mres-v1612.map" "$work/mres.txt" \
        "$work/$mutant" "$build/../user/init-v1614.c" \
        "$build/../user/init.dxr" "$build/../user/comp-v1638.dxr" \
        "$build/../tsfs-root-v1638.manifest" \
        >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1641: fake $mutant physical witness accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1641 simulated FULL loader rollback:' \
        "$work/$mutant.log"
done
echo 'PASS v1641: forged retained pin and false loader success rejected'
