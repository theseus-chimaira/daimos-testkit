#!/bin/sh
# Test-only 48K physical STOP -> PACKED -> foreign TERM admission gate.
# No MM fault/pin injection; this is a prerequisite to terminal PI6.
set -eu
: "${DAIMOS_REPO:?original PURE development source checkout required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=${V1682_WORK_DIR:-$(mktemp -d "$TMPDIR/daimos-v1682-stop-term.XXXXXX")}
mkdir -p "$work"
case "${V1682_VARIANT:-general}" in
    general|strict) ;;
    *) echo 'FAIL v1682: bad source-matched variant' >&2; exit 2 ;;
esac
# Do not set V1673_FIXTURE_BUILD on the first run: the genuine source
# builder must compile this new C89 PID1 and its separate pure child.
V1673_ONLY_VARIANT=${V1682_VARIANT:-general} \
V1673_GUEST_C="$here/proc-pressure-v1682.c" \
V1673_CHILD_ASM="$here/spin-child-v1682.s" \
V1673_CTY_DRIVER="$here/host-cty-v1682.py" \
V1673_MEASURE="$here/measure-v1682.py" \
V1673_WORK_DIR="$work" \
V1673_TIMEOUT=${V1673_TIMEOUT:-3600} \
KEEP_TEST=1 sh "$kit/tests/validation/pure-runtime-reclaim-v1673/run-physical-v1673.sh"
echo "PASS v1682: STOP/user-PC PACKED foreign TERM source control (${V1682_VARIANT:-general})"
echo "v1682 original physical evidence: $work"
echo 'NOT ACCEPTED: pinned owner terminal PI6/unknown MM pin, full physical matrix'
