#!/bin/sh
# Rebuild-independent physical PDP-6 48K source-linked bounded FULL
# with genuine secondary DTC3 read error, subsequent successful retry.
set -eu
: "${DAIMOS_REPO:?DAIMOS source repository required}"
: "${PURE_FULL_BUILD_V1654:?source-built 48K v1654 guest/build required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
original=$(CDPATH= cd -- "$here/../../diagnostics/pure-secondary-read-v1643" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-full-physical-v1654.XXXXXX")
trap 'echo "v1654 corrected original physical verification: $work"' EXIT HUP INT TERM
export P1E_V1654_ORIGINAL_DIR="$original"
export P1E_V1654_GENERATED_DIR="$work"
python3 "$here/prepare-physical-v1654.py" "$original" "$PURE_FULL_BUILD_V1654" "$work"
sh -n "$work/replay-derived-v1654.sh" "$work/run-audit-derived-v1654.sh"
export PURE_SECONDARY_BUILD_V1643="$PURE_FULL_BUILD_V1654"
export PURE_SECONDARY_TIMEOUT_V1643=${PURE_FULL_TIMEOUT_V1654:-900}
sh "$work/replay-derived-v1654.sh" >"$work/replay-v1654.log" 2>&1 || {
    tail -65 "$work/replay-v1654.log" >&2
    echo 'FAIL v1654: original 48K physical FULL replay' >&2
    exit 1
}
trace=$(sed -n 's/^v1643 original source-linked physical evidence: //p' "$work/replay-v1654.log" | tail -1)
test -n "$trace"
test -s "$trace/trace.clean"
export PURE_SECONDARY_TRACE_V1643="$trace/trace.clean"
sh "$work/run-audit-derived-v1654.sh" >"$work/audit-v1654.log" 2>&1 || {
    tail -75 "$work/audit-v1654.log" >&2
    echo 'FAIL v1654: source-linked original physical MM auditor' >&2
    exit 1
}
cat "$work/audit-v1654.log"
echo 'PASS v1654: original 48K physical DTC3 FULL read fault/rollback/retry/WAIT'
