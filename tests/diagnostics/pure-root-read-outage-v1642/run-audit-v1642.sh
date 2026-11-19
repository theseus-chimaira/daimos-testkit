#!/bin/sh
# Audits a REAL missing-TSFS-root-member transfer during FULL restore.
# A selected-root failure must stop the machine, not retry or WAIT.
set -eu
: "${DAIMOS_REPO:?original matching DAIMOS source required}"
: "${PURE_ROOT_OUTAGE_BUILD_V1642:?original v1638 build required}"
: "${PURE_ROOT_OUTAGE_TRACE_V1642:?actual physical root-failure trace required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-root-read-outage-audit-v1642.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
build="$PURE_ROOT_OUTAGE_BUILD_V1642"
"$PDP10_PREFIX/bin/dxrcheck" -d "$build/pure-mres-v1612.dxr" \
    >"$work/mres.txt"
set -- "$build/kcore.map" "$build/pure-mres-v1612.map" \
    "$work/mres.txt" "$PURE_ROOT_OUTAGE_TRACE_V1642" \
    "$build/../user/init-v1614.c" \
    "$build/../tsfs-root-v1638.manifest" \
    "$DAIMOS_REPO/system/kernel/fs/tsfs_runtime.s" \
    "$DAIMOS_REPO/system/kernel/proc/proc_storage_runtime_v30.s"
python3 "$here/audit-v1642.py" "$@"

python3 - "$PURE_ROOT_OUTAGE_TRACE_V1642" \
    "$work/fake-mount" "$work/fake-halt" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1]).read_text(encoding="ascii")
start = "V1642_ROOT_FAILURE_CLASSIFIER\n"
end = "V1642_STAGE_REAL_IO_FAILURE\n"
assert source.count(start) == source.count(end) == 1
before, tail = source.split(start, 1)
section, after = tail.split(end, 1)
root_id = re.search(r"(?m)^2:\s*([0-7]{1,12})\s*$", section)
assert root_id
old = root_id.group(0)
new = re.sub(r"([0-7]+)$", "7", old)
assert old != new
Path(sys.argv[2]).write_text(before + start + section.replace(old, new, 1)
                              + end + after, encoding="ascii")
match = re.search(r"HALT instruction, PC: ([0-7]{6})", source)
assert match
new_pc = "%06o" % (int(match.group(1), 8) + 1)
Path(sys.argv[3]).write_text(source.replace(match.group(0),
                              "HALT instruction, PC: " + new_pc, 1),
                              encoding="ascii")
PY
for mutant in fake-mount fake-halt; do
    if python3 "$here/audit-v1642.py" "$build/kcore.map" \
        "$build/pure-mres-v1612.map" "$work/mres.txt" \
        "$work/$mutant" "$build/../user/init-v1614.c" \
        "$build/../tsfs-root-v1638.manifest" \
        "$DAIMOS_REPO/system/kernel/fs/tsfs_runtime.s" \
        "$DAIMOS_REPO/system/kernel/proc/proc_storage_runtime_v30.s" \
        >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1642: accepted forged $mutant root-loss witness" >&2
        exit 1
    fi
    grep -q '^FAIL v1642 physical root FULL read:' "$work/$mutant.log"
done
echo 'PASS v1642: forged wrong root mount and fake HALT PC rejected'
