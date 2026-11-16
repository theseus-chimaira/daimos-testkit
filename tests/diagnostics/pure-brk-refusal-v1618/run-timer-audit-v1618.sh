#!/bin/sh
# Inspect the same real 48K PDP-6 twice or more during Type-551 search.
# This does not certify successful PURE-prefix restore.
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
: "${PURE_DTC_BUILD_V1618:?48K image with 120s DECtape MRES required}"
: "${PURE_DTC_TRACE_V1618:?physical timed SIMH trace required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-dtc-audit-v1618.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

audit()
{
    python3 "$here/audit-timer-v1618.py" \
        "$PURE_DTC_BUILD_V1618/kcore.map" \
        "$PURE_DTC_BUILD_V1618/tape-mres.dxr" \
        "$DAIMOS_REPO/system/kernel/drivers/tape_io.s" \
        "$DAIMOS_REPO/system/kernel/storage/storage_router.s" \
        "$1" "$PDP10_PREFIX/bin/dxrcheck"
}

audit "$PURE_DTC_TRACE_V1618"

# Private unsafe mutation: replace the new initial 120-second clock
# deadline with the obsolete 45-second value while preserving all
# other physical observations.
python3 - "$PURE_DTC_TRACE_V1618" "$work/old-timeout.clean" <<'PY'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text()
old = "777777761740"
assert old in text, "missing physical 120-second countdown"
Path(sys.argv[2]).write_text(text.replace(old, "777777772564", 1))
PY
if audit "$work/old-timeout.clean" >"$work/mutant.log" 2>&1; then
    echo 'FAIL v1618: obsolete 45s physical timer accepted' >&2
    exit 1
fi
grep -q '^FAIL v1618 timer audit:' "$work/mutant.log" || {
    cat "$work/mutant.log" >&2
    exit 1
}
echo 'PASS v1618: old 45s countdown rejected in physical trace'
