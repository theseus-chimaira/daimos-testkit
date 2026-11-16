#!/bin/sh
# Verify the source-matched physical RUN failure and reject forged evidence.
set -eu
: "${PURE_RUN_BUILD_V1625:?original six-child build required}"
: "${PURE_RUN_TRACE_V1625:?original breakpoint trace required}"
: "${DAIMOS_REPO:?source checkout matching the KCORE image required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-run-audit-v1625.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
map="$PURE_RUN_BUILD_V1625/kcore.map"
exec_source="$DAIMOS_REPO/system/kernel/proc/exec_load.s"
run_source="$DAIMOS_REPO/system/kernel/proc/proc_run.s"
python3 "$here/audit-v1625.py" "$map" "$PURE_RUN_TRACE_V1625" \
    "$exec_source" "$run_source"
python3 - "$PURE_RUN_TRACE_V1625" "$work/ac-mutant" \
    "$work/pc-mutant" <<'PY'
from pathlib import Path
import sys
original = Path(sys.argv[1]).read_text(encoding="ascii")
old_ac = "1:\t777777777776"
old_pc = "Breakpoint, PC: 017725 ("
assert original.count(old_ac) == 1
assert original.count(old_pc) == 1
Path(sys.argv[2]).write_text(original.replace(
    old_ac, "1:\t777777777777", 1), encoding="ascii")
Path(sys.argv[3]).write_text(original.replace(
    old_pc, "Breakpoint, PC: 017724 (", 1), encoding="ascii")
PY
for mutant in ac-mutant pc-mutant; do
    if python3 "$here/audit-v1625.py" "$map" "$work/$mutant" \
        "$exec_source" "$run_source" >"$work/$mutant.out" 2>&1; then
        echo "FAIL v1625: $mutant was accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1625 RUN stage audit:' "$work/$mutant.out"
done
echo 'PASS v1625: false AC1 return and wrong RUN PC both rejected'
