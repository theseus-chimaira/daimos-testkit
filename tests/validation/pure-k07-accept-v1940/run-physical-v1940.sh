#!/bin/sh
# First physical gate: original mixed plain/compressed 48K workload.
# A lifecycle PASS alone does not establish the FULL geometry or K07.
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR DAIMOS_REPO
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
for phase in KCC KCPP KPARSE KGEN KOPT; do
    test -s "$PDP10_PREFIX/lib/kcc/bootstrap/$phase.dxr" || {
        echo "Missing installed native KCC bootstrap: $phase.dxr" >&2
        exit 1
    }
done
work=$(mktemp -d "$TMPDIR/pure-k07-physical-v1940.XXXXXX")
trap 'echo "v1940 physical fixture evidence: $work"' EXIT
git -C "$DAIMOS_REPO" rev-parse HEAD > "$work/daimos.commit"
git -C "$kit" rev-parse HEAD > "$work/testkit.commit"
git -C "$DAIMOS_REPO" diff > "$work/daimos.diff"
python3 "$kit/tests/diagnostics/pure-full-restore-v1638/prepare-v1638.py" \
    "$kit/tests/diagnostics/pure-brk-pressure-v1614/test-v1614.c" \
    "$work/init-v1940.c"
export PURE_BRK_SOURCE_V1615="$work/init-v1940.c"
export PURE_TSFS_PRE_SIM_V1638="$kit/tests/diagnostics/pure-full-restore-v1638/prepare-media-v1638.sh"
export PURE_PHYS_KWORDS_V1626=48 PURE_ENABLE_V1631=1
export PURE_LIFECYCLE_ONLY_V1627=1 PURE_MM_DUMP_V1615=1 KEEP_TEST=1
# Physical Type-551 search and transfer use real timing. A short
# diagnostic limit can expire after a successful boot/child RUN.
export PURE_PRESSURE_TIMEOUT_V1614=${PURE_PRESSURE_TIMEOUT_V1614:-1150}
rc=0
sh "$kit/tests/diagnostics/pure-brk-pressure-v1614/run-v1614.sh" \
    > "$work/physical.log" 2>&1 || rc=$?
tail -80 "$work/physical.log"
if [ "$rc" -ne 0 ]; then
    echo "K07 physical lifecycle incomplete; see preserved console/MM evidence" >&2
    exit "$rc"
fi
# The historical lifecycle runner checks a broad marker order. Require
# the six checked waits and normal HALT before reporting this gate.
guest=$(sed -n 's/^v1614: pressure guest evidence //p' "$work/physical.log" | tail -1)
test -n "$guest"
python3 - "$guest/console.clean" <<'PY'
from pathlib import Path
import re, sys
s = Path(sys.argv[1]).read_text()
assert "PURE                              LOADED" in s
assert re.search(r"aaaaaax\[B", s), "six checked RUNs and seventh refusal missing"
assert re.search(r"wwwwwwZ", s), "six child completions and checked WAITs missing"
assert "HALT instruction" in s, "normal HALT missing"
print("PASS v1940 mixed TSFS lifecycle (not FULL geometry/PI6 acceptance)")
PY
