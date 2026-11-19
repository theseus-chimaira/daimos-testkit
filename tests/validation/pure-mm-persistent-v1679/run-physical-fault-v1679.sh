#!/bin/sh
# v1679 physical 48K real MM precommit rebase refusal; fixed KCORE unchanged.
# Run one profile at a time with a source-linked injected MRES build.
set -eu
: "${DAIMOS_REPO:?source-matched PURE checkout required}"
: "${V1679_VARIANT:?select general or strict}"
: "${V1679_BUILD:?absolute source-built injected image directory}"
: "${V1679_FIXTURE:?exact deterministic pipe fixture directory}"
case "$V1679_VARIANT" in general|strict) ;; *) exit 2 ;; esac
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
v1674="$kit/tests/validation/pure-runtime-highwater-v1674"
v1673="$kit/tests/validation/pure-runtime-reclaim-v1673"
work=${V1679_WORK_DIR:-$(mktemp -d "$TMPDIR/daimos-v1679-physical-fault.XXXXXX")}
mkdir -p "$work"
for f in "$V1679_BUILD/kcore.map" \
         "$V1679_BUILD/pure-mres-v1612.map" \
         "$V1679_BUILD/pure-mres-v1612.dxr" \
         "$V1679_BUILD/boot.ini" \
         "$V1679_FIXTURE/v1673-test-init.map"; do
    test -s "$f" || { echo "Missing v1679 source file: $f" >&2; exit 1; }
done
grep -q '^v1679_rebase_fault_count[[:space:]]' \
    "$V1679_BUILD/pure-mres-v1612.map" || {
    echo 'FAIL v1679: PURE test-only fault counter absent' >&2
    exit 1
}
V1679_PURE_MAP="$V1679_BUILD/pure-mres-v1612.map" \
V1673_ONLY_VARIANT="$V1679_VARIANT" \
V1673_WORK_DIR="$work" \
V1673_GENERAL_BUILD="$V1679_BUILD" \
V1673_STRICT_BUILD="$V1679_BUILD" \
V1673_FIXTURE_BUILD="$V1679_FIXTURE" \
V1673_GUEST_C="$v1674/proc-pressure-v1674.c" \
V1673_CHILD_ASM="$v1674/pipe-child-v1674.s" \
V1673_CTY_DRIVER="$here/host-cty-fault-v1679.py" \
V1673_MEASURE="$here/measure-v1679.py" \
V1673_TIMEOUT=${V1673_TIMEOUT:-3600} \
KEEP_TEST=1 sh "$v1673/run-physical-v1673.sh"
variant=$V1679_VARIANT
python3 "$here/verify-fault-v1679.py" \
    "$work/$variant-48-console.clean" "$V1679_BUILD/kcore.map" \
    "$V1679_BUILD/pure-mres-v1612.map"
python3 "$here/test-fault-negative-v1679.py" \
    "$work/$variant-48-console.clean" "$V1679_BUILD/kcore.map" \
    "$V1679_BUILD/pure-mres-v1612.map" "$work/unsafe-witness-v1679"
python3 "$here/run-negative-v1679.py" \
    "$work/$variant-48-console.clean" \
    "$V1679_FIXTURE/v1673-test-init.map" "$V1679_BUILD/kcore.map" \
    "$work/$variant-48-report.json" "$work/unsafe-mm-v1679" "$variant"
if [ "${V1679_FAST:-0}" = 1 ]; then
    echo "PASS v1679: $variant original physical A/B/C, three-or-more original rebase refusals and MM/PROC negative suite"
    echo "v1679 scoped no-write-watch evidence: $work"
    echo 'NOT ACCEPTED: continuous physical MM writes and full PI6 fault matrix'
    exit 0
fi
python3 "$v1674/trace-v1674.py" \
    "$V1679_FIXTURE/v1673-test-init.map" "$V1679_BUILD/kcore.map" \
    "$work/$variant-48-console.clean" \
    "$work/$variant-48-report.json" \
    "$work/$variant-48-highwater.json"
KEEP_TEST=1 sh "$v1674/run-negative-v1674.sh" \
    "$work/$variant-48-console.clean" \
    "$V1679_FIXTURE/v1673-test-init.map" "$V1679_BUILD/kcore.map" \
    "$work/$variant-48-report.json" \
    "$work/$variant-48-highwater.json"
echo "PASS v1679: $variant real 48K physical fault-injected RAW PURE"
echo "v1679 evidence: $work"
echo 'NOT YET ACCEPTED: paired general/strict and actual MM fault recovery remain separate gates'
