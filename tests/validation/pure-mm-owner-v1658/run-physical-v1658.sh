#!/bin/sh
# Source-built original 48K DTC3 unplug/read-error/restore/WAIT physical test.
set -eu
: "${DAIMOS_REPO:?exact DAIMOS v1658 source required}"
: "${PURE_MM_BUILD_V1658:?fresh v1658 48K physical build required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
original=$(CDPATH= cd -- "$here/../../diagnostics/pure-secondary-read-v1643" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-mm-physical-v1658.XXXXXX")
trap 'echo "v1658 independent physical evidence: $work"' EXIT HUP INT TERM
export P1E_V1658_ORIGINAL_DIR="$original"
export P1E_V1658_GENERATED_DIR="$work"
python3 "$here/prepare-physical-v1658.py" "$original" \
    "$PURE_MM_BUILD_V1658" "$work" "$PDP10_PREFIX/bin/dxrcheck"
sh -n "$work/replay-derived-v1658.sh" "$work/run-audit-derived-v1658.sh"
export PURE_SECONDARY_BUILD_V1643="$PURE_MM_BUILD_V1658"
export PURE_SECONDARY_TIMEOUT_V1643=${PURE_MM_TIMEOUT_V1658:-950}
sh "$work/replay-derived-v1658.sh" >"$work/replay.log" 2>&1 || {
    tail -80 "$work/replay.log" >&2
    exit 1
}
trace=$(sed -n 's/^v1643 original source-linked physical evidence: //p' \
    "$work/replay.log" | tail -1)
test -n "$trace"
test -s "$trace/trace.clean"
export PURE_SECONDARY_TRACE_V1643="$trace/trace.clean"
sh "$work/run-audit-derived-v1658.sh" >"$work/audit.log" 2>&1 || {
    tail -80 "$work/audit.log" >&2
    exit 1
}
cat "$work/audit.log"
echo 'PASS v1658: independent physical secondary DTC3 FULL rollback and WAIT'
