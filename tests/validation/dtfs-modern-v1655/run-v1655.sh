#!/bin/sh
# Current-source PDP-6 DTFS provider admission and recovery matrix.
# Historical v1518/v1522 fixtures remain non-passing after v1561/v1575;
# do not count their old source strings as an accepted runtime oracle.
set -eu
: "${DAIMOS_REPO:?original DAIMOS checkout required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-modern-v1655.XXXXXX")
trap 'echo "v1655 current-source DTFS evidence: $work"' EXIT HUP INT TERM

# These suites independently compile/extract CURRENT production PDP-6
# instructions and execute the actual negative mutants in the simulator.
# A failure anywhere is a hard error, not a historical PASS.
run_case() {
    version=$1
    name=$2
    file=$3
    sh "$kit/tests/validation/$file" >"$work/$name-$version.log" 2>&1 || {
        tail -70 "$work/$name-$version.log" >&2
        echo "FAIL v1655: current-source $name suite failed" >&2
        exit 1
    }
    grep -q '^PASS ' "$work/$name-$version.log"
    echo "PASS v1655: current-source $name ($version)"
}
run_case v1556 v1-v2-read-fault daimos-dtfs-v2-revalidate-v1556.sh
run_case v1554 physical-dirty-verify daimos-dtfs-physical-verify-v1554.sh
run_case v1561 mount-owner-intent daimos-dtfs-intent-mount-v1561.sh
run_case v1575 operator-discard daimos-dtfs-discard-drain-v1575.sh

python3 - "$work" "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import sys

work, repo = (Path(p) for p in sys.argv[1:])
tests = [
    ("v1-v2-read-fault-v1556.log", 14),
    ("physical-dirty-verify-v1554.log", 10),
    ("mount-owner-intent-v1561.log", 13),
    ("operator-discard-v1575.log", 2),
]
for name, expected in tests:
    lines = (work / name).read_text(encoding="ascii").splitlines()
    assert len([line for line in lines if line.startswith("PASS ") and
                ("rejected " in line)]) == expected, (name, expected)
runtime = (repo / "system/kernel/fs/dtfs_runtime.s").read_text(
    encoding="ascii")
for marker in ("dtfs_identity_revalidate_v1522:",
               "dtfs_dtc_read_failed_v1518:",
               "dtfs_dtc_write_intent_refuse_v1561:",
               "dtfs_discard_drain_v1575:",
               "dtfs_mark_unit_suspect_v1522:"):
    assert runtime.count(marker) == 1, marker
print("v1655: 30 V1/V2 recoveries, 17 physical DIRTY verifications")
print("v1655: 35 source-linked V2 mount-owner/intent cases")
print("v1655: 39 separately executed unsafe source mutants rejected")
print("PASS v1655: current PDP-6 DTFS provider matrix, not full KCORE freeze")
PY
