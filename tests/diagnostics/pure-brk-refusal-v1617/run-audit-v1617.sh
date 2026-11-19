#!/bin/sh
# Audit actual kernel trampolines, original linked DXR, and a late
# physical CPU PC; test-only mutations must be rejected.
set -eu
: "${DAIMOS_REPO:?source checkout required}"
: "${PURE_BRK_BUILD_V1615:?matching physical PDP-6 build required}"
: "${PURE_MODULE_PROBE_TRACE_V1617:?trampoline examination required}"
: "${PURE_INTERRUPTED_TRACE_V1616:?interrupted CPU trace required}"
: "${PURE_TAPE_WAIT_TRACE_V1617:?live DECtape wait trace required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-module-origin-v1617.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

audit()
{
    python3 "$here/audit-module-origin-v1617.py" \
        "$PURE_BRK_BUILD_V1615/kcore.map" \
        "$PURE_BRK_BUILD_V1615/pure-mres-v1612.map" \
        "$PURE_BRK_BUILD_V1615/tape-mres.dxr" "$1" \
        "$PURE_INTERRUPTED_TRACE_V1616" \
        "$DAIMOS_REPO/system/kernel/drivers/tape_io.s" \
        "$PDP10_PREFIX/bin/dxrcheck" "$2"
}

audit "$PURE_MODULE_PROBE_TRACE_V1617" "$PURE_TAPE_WAIT_TRACE_V1617"
python3 - "$PURE_MODULE_PROBE_TRACE_V1617" "$work/mutant.clean" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
old = '254000032375'
assert s.count(old) == 1, 'scheduler service trampoline drifted'
Path(sys.argv[2]).write_text(s.replace(old, '254000032376', 1))
PY
if audit "$work/mutant.clean" "$PURE_TAPE_WAIT_TRACE_V1617" \
    >"$work/mutant.log" 2>&1; then
    echo 'FAIL v1617: one-word-shifted PURE MRES export accepted' >&2
    exit 1
fi
grep -q '^FAIL v1617 module attribution:' "$work/mutant.log" || {
    cat "$work/mutant.log" >&2
    exit 1
}
echo 'PASS v1617: unsafe PURE service-export mutation rejected'

python3 - "$PURE_TAPE_WAIT_TRACE_V1617" "$work/timer-mutant.clean" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
old = '777777772564'
assert s.count(old) == 1, 'physical tape countdown drifted'
Path(sys.argv[2]).write_text(s.replace(old, '777777772565', 1))
PY
if audit "$PURE_MODULE_PROBE_TRACE_V1617" "$work/timer-mutant.clean" \
    >"$work/timer-mutant.log" 2>&1; then
    echo 'FAIL v1617: mutated DECtape initial timeout accepted' >&2
    exit 1
fi
grep -q '^FAIL v1617 module attribution:' "$work/timer-mutant.log" || {
    cat "$work/timer-mutant.log" >&2
    exit 1
}
echo 'PASS v1617: unsafe DECtape timeout mutation rejected'
