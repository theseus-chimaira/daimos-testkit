#!/bin/sh
# Verify physical five-owner on/off memory accounting and reject
# forged PACKED and PROCESS owner mutations on both source maps.
set -eu
: "${PURE_ON_CASE_V1632:?original v1629 enabled guest required}"
: "${PURE_OFF_CASE_V1632:?original v1631 disabled guest required}"
: "${PURE_ON_TRACE_V1632:?original v1629 B/A/Z MM trace required}"
: "${PURE_OFF_TRACE_V1632:?new pre-sixth RUN MM trace required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-equal-five-audit-v1632.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 "$here/audit-v1632.py" "$PURE_ON_CASE_V1632" \
    "$PURE_OFF_CASE_V1632" "$PURE_ON_TRACE_V1632" \
    "$PURE_OFF_TRACE_V1632"
python3 - "$PURE_ON_CASE_V1632/build/kcore.map" \
    "$PURE_ON_TRACE_V1632" "$PURE_OFF_TRACE_V1632" \
    "$work/on-forgery" "$work/off-forgery" <<'PY'
from pathlib import Path
import re
import sys
symbols = {}
for line in Path(sys.argv[1]).read_text(encoding="ascii").splitlines():
    f = line.split()
    if len(f) >= 2 and re.fullmatch(r"[0-7]+", f[1]):
        symbols[f[0]] = int(f[1], 8)


def change_owner(trace, head, tail, oldkind, oldowner, newkind,
                 newowner):
    assert trace.count(head) == 1 and trace.count(tail) == 1
    prefix, remaining = trace.split(head, 1)
    segment, suffix = remaining.split(tail, 1)
    words = {int(a, 8): int(w, 8) for a, w in re.findall(
        r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", segment)}
    count = words[symbols["mm_extent_count"]]
    found = []
    for i in range(count):
        address = symbols["mm_extents"] + 2 * i + 1
        meta = words[address]
        if ((meta >> 18) & 7) == oldkind and (meta & 0o777777) == oldowner:
            found.append((address, meta))
    assert len(found) == 1
    address, meta = found[0]
    old = "%o:\t%012o" % (address, meta)
    new_meta = ((meta & ~(0o7 << 18)) | (newkind << 18))
    new_meta = (new_meta & ~0o777777) | newowner
    new = "%o:\t%012o" % (address, new_meta)
    assert segment.count(old) == 1
    return prefix + head + segment.replace(old, new, 1) + tail + suffix


on = Path(sys.argv[2]).read_text(encoding="ascii")
off = Path(sys.argv[3]).read_text(encoding="ascii")
Path(sys.argv[4]).write_text(change_owner(
    on, "V1629_STAGE_B\n", "V1629_END_B\n", 4, 6, 1, 6),
    encoding="ascii")
Path(sys.argv[5]).write_text(change_owner(
    off, "V1632_FIVE_READY\n", "V1632_END_FIVE\n", 1, 6, 1, 7),
    encoding="ascii")
PY
for mutant in on-forgery off-forgery; do
    on="$PURE_ON_TRACE_V1632"
    off="$PURE_OFF_TRACE_V1632"
    case "$mutant" in
    on-forgery) on="$work/$mutant" ;;
    off-forgery) off="$work/$mutant" ;;
    esac
    if python3 "$here/audit-v1632.py" "$PURE_ON_CASE_V1632" \
        "$PURE_OFF_CASE_V1632" "$on" "$off" \
        >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1632: $mutant accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1632 equal-five MM audit:' "$work/$mutant.log"
done
echo 'PASS v1632: false PACKED-to-PROCESS and duplicated owner rejected'
