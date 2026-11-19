#!/bin/sh
# Require the ORIGINAL physical write-event oracle to reject corruptions.
set -eu
: "${DAIMOS_REPO:?original DAIMOS source worktree required}"
if [ "$#" -ne 5 ]; then
    echo 'usage: run-negative-v1674.sh console fixture.map kcore.map v1673-report v1674-report' >&2
    exit 2
fi
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-v1674-highwater-negative.XXXXXX")
keep=${KEEP_TEST:-0}
cleanup()
{
    if [ "$keep" = 1 ]; then
        echo "v1674 high-water unsafe-mutant evidence: $work"
    else
        rm -rf "$work"
    fi
}
trap cleanup EXIT HUP INT TERM
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
console=$1; fixture=$2; coremap=$3; accepted1673=$4; accepted1674=$5
for f in "$console" "$fixture" "$coremap" "$accepted1673" "$accepted1674"; do
    test -s "$f"
done
python3 "$here/trace-v1674.py" "$fixture" "$coremap" \
    "$console" "$accepted1673" "$work/positive.json" > "$work/positive.log"
cmp "$work/positive.json" "$accepted1674" || {
    echo 'FAIL v1674: positive physical trace cannot be reproduced' >&2
    keep=1; exit 1
}
count=$(awk '$1=="mm_extent_count" {print $2}' "$coremap")
test -n "$count"
python3 - "$console" "$accepted1674" "$work" "$count" <<'PY'
import json
import re
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text(encoding="ascii")
report = json.loads(Path(sys.argv[2]).read_text(encoding="ascii"))
work = Path(sys.argv[3])

# Remove a single actual installed SIMH watchpoint from the A setup.
pat = r"(?m)^(?:sim> )?SET BREAK -W [0-7]+;[^\n]*\n"
if len(re.findall(pat, source)) != 71:
    raise SystemExit("v1674: installed physical watch list drift")
mutant = re.sub(pat, "", source, count=1)
(work / "unsafe-missing-watch.log").write_text(mutant, encoding="ascii")

# Corrupt the last actual count-commit write before B, not a
# synthetic added line. Replay must refuse the invalid owner table.
start = source.index("V1673 RELEASE A")
end = source.index("V1673 HOLD B", start)
window = source[start:end]
pat = (r"(?m)^(Breakpoint, PC: [^\n]*\n(?:sim> )?"
       r"([0-7]{3,7}):[ \t]+)([0-7]{12})([ \t]*)$")
hits = list(re.finditer(pat, window))
if len(hits) < 5:
    raise SystemExit("v1674: no original physical MM write stream")
# The actual count address comes from the source-built kernel map.
count_address = int(sys.argv[4], 8)
commits = [m for m in hits if int(m.group(2), 8) == count_address]
if not commits:
    raise SystemExit("v1674: no original MM count-commit watch")
first = commits[-1]
window = window[:first.start(3)] + "777777777777" + window[first.end(3):]
(work / "unsafe-mutation-value.log").write_text(
    source[:start] + window + source[end:], encoding="ascii")

# Delete an actual original write event, including its matched action.
window = source[start:end]
match = commits[-1]
window = window[:match.start()] + window[match.end():]
(work / "unsafe-missing-write.log").write_text(
    source[:start] + window + source[end:], encoding="ascii")

# Forge a high-water maximum in a successful physical JSON, not in the
# underlying original console data.
report["max_event_nonfree"] += 1
(work / "unsafe-peak.json").write_text(
    json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="ascii")
PY
for mutant in unsafe-missing-watch unsafe-mutation-value unsafe-missing-write; do
    if python3 "$here/trace-v1674.py" \
        "$fixture" "$coremap" "$work/$mutant.log" "$accepted1673" \
        "$work/$mutant.json" > "$work/$mutant-refused.log" 2>&1; then
        echo "FAIL v1674: unsafe $mutant physical trace accepted" >&2
        keep=1; exit 1
    fi
    grep -q '^FAIL v1674 physical high-water replay:' \
        "$work/$mutant-refused.log" || {
        cat "$work/$mutant-refused.log" >&2
        keep=1; exit 1
    }
    echo "v1674: rejected executed $mutant original-physical mutation"
done
if python3 "$here/compare-v1674.py" "$accepted1674" \
    "$work/unsafe-peak.json" > "$work/unsafe-peak-refused.log" 2>&1; then
    echo 'FAIL v1674: forged high-water summary accepted' >&2
    keep=1; exit 1
fi
grep -q '^FAIL v1674 paired original-MM high-water:' \
    "$work/unsafe-peak-refused.log" || {
    cat "$work/unsafe-peak-refused.log" >&2
    keep=1; exit 1
}
echo 'PASS v1674: original MM watch list, write-value, missing-event and summary mutants rejected'
