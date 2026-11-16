#!/bin/sh
# Compare original source-identical PURE-ON/OFF 48K guests and reject
# a forged resident owner or missing sixth RUN acceptance.
set -eu
: "${PURE_ON_CASE_V1631:?original v1629 PURE-ON case required}"
: "${PURE_OFF_CASE_V1631:?original v1631 PURE-OFF case required}"
: "${PURE_OFF_TRACE_V1631:?genuine six-owner MM snapshot required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-capacity-audit-v1631.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 "$here/audit-v1631.py" "$PURE_ON_CASE_V1631" \
    "$PURE_OFF_CASE_V1631" "$PURE_OFF_TRACE_V1631"
python3 - "$PURE_OFF_TRACE_V1631" "$PURE_OFF_CASE_V1631/build/kcore.map" \
    "$work/wrong-owner" "$work/no-sixth" <<'PY'
from pathlib import Path
import re
import sys
trace = Path(sys.argv[1]).read_text(encoding="ascii")
symbols = {}
for line in Path(sys.argv[2]).read_text(encoding="ascii").splitlines():
    p = line.split()
    if len(p) >= 2 and re.fullmatch(r"[0-7]+", p[1]):
        symbols[p[0]] = int(p[1], 8)
prefix, rest = trace.split("V1631_SIX_RUN_ACCEPTED\n", 1)
segment, suffix = rest.split("V1631_END_SIX_RUN\n", 1)
words = {int(a, 8): int(w, 8) for a, w in re.findall(
    r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", segment)}
count = words[symbols["mm_extent_count"]]
owners = []
for i in range(count):
    address = symbols["mm_extents"] + 2 * i + 1
    meta = words[address]
    if ((meta >> 18) & 7) == 1 and (meta & 0o777777) == 7:
        owners.append((address, meta))
assert len(owners) == 1
address, meta = owners[0]
old = "%o:\t%012o" % (address, meta)
new = "%o:\t%012o" % (address, (meta & ~0o777777) | 8)
assert segment.count(old) == 1
Path(sys.argv[3]).write_text(
    prefix + "V1631_SIX_RUN_ACCEPTED\n" +
    segment.replace(old, new, 1) + "V1631_END_SIX_RUN\n" + suffix,
    encoding="ascii")
assert trace.count("aaaaa!u") == 1
Path(sys.argv[4]).write_text(trace.replace(
    "aaaaa!u", "aaaaa!v", 1), encoding="ascii")
PY
for mutant in wrong-owner no-sixth; do
    if python3 "$here/audit-v1631.py" "$PURE_ON_CASE_V1631" \
        "$PURE_OFF_CASE_V1631" "$work/$mutant" \
        >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1631: forged $mutant physical evidence accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1631 matched physical admission:' "$work/$mutant.log"
done
echo 'PASS v1631: foreign PROCESS owner and forged sixth RUN rejected'
