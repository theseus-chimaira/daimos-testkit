#!/bin/sh
# Source-matched six-owner 48K PURE-on/OFF physical free-word comparison.
# Require identical user source and KCORE, correct 1758-word MRES cost,
# and reject forged resident owners or a forged final WAIT success.
set -eu
: "${PURE_ON_CASE_V1639:?original v1637 PURE-on case required}"
: "${PURE_OFF_CASE_V1639:?v1639 PURE-off control case required}"
: "${PURE_ON_TRACE_V1639:?original v1637 B/A/Z physical trace required}"
: "${PURE_OFF_TRACE_V1639:?original v1639 B/A/Z physical trace required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-six-matched-audit-v1639.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 "$here/audit-v1639.py" \
    "$PURE_ON_CASE_V1639" "$PURE_OFF_CASE_V1639" \
    "$PURE_ON_TRACE_V1639" "$PURE_OFF_TRACE_V1639"
python3 - "$PURE_OFF_CASE_V1639/build/kcore.map" \
    "$PURE_OFF_TRACE_V1639" "$work/duplicate-owner" \
    "$work/false-wait" <<'PY'
from pathlib import Path
import re
import sys

sym = {}
for line in Path(sys.argv[1]).read_text(encoding="ascii").splitlines():
    f = line.split()
    if len(f) >= 2 and re.fullmatch(r"[0-7]+", f[1]):
        sym[f[0]] = int(f[1], 8)
text = Path(sys.argv[2]).read_text(encoding="ascii")
first, last = "V1639_STAGE_B\n", "V1639_END_B\n"
assert text.count(first) == text.count(last) == 1
pre, rem = text.split(first, 1)
seg, post = rem.split(last, 1)
words = {int(a, 8): int(b, 8) for a, b in re.findall(
    r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", seg)}
targets = []
for i in range(words[sym["mm_extent_count"]]):
    addr = sym["mm_extents"] + 2 * i + 1
    meta = words[addr]
    if (meta & 0o777777) == 7 and ((meta >> 18) & 7) == 1:
        targets.append((addr, meta))
assert len(targets) == 1
addr, meta = targets[0]
old = "%o:\t%012o" % (addr, meta)
new = "%o:\t%012o" % (addr, (meta & ~0o777777) | 6)
assert seg.count(old) == 1
Path(sys.argv[3]).write_text(pre + first + seg.replace(old, new, 1)
                              + last + post, encoding="ascii")
marker = "LwwwwwwZV1639_STAGE_Z"
assert text.count(marker) == 1
Path(sys.argv[4]).write_text(text.replace(
    marker, "LwwwwwwYV1639_STAGE_Z", 1), encoding="ascii")
PY
for mutant in duplicate-owner false-wait; do
    if python3 "$here/audit-v1639.py" \
        "$PURE_ON_CASE_V1639" "$PURE_OFF_CASE_V1639" \
        "$PURE_ON_TRACE_V1639" "$work/$mutant" \
        >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1639: accepted corrupted $mutant MM/WAIT evidence" >&2
        exit 1
    fi
    grep -q '^FAIL v1639 matched physical six-child audit:' \
        "$work/$mutant.log"
done
echo 'PASS v1639: false resident owner and false parent WAIT rejected'
