#!/bin/sh
# v1678 physical 48K MRES MM-rebase-refusal reply test; KCORE is unchanged.
# Run one profile at a time with a source-linked injected MRES build.
set -eu
: "${DAIMOS_REPO:?source-matched PURE checkout required}"
: "${V1678_VARIANT:?select general or strict}"
: "${V1678_BUILD:?absolute source-built injected image directory}"
: "${V1678_FIXTURE:?exact deterministic pipe fixture directory}"
case "$V1678_VARIANT" in general|strict) ;; *) exit 2 ;; esac
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
v1674="$kit/tests/validation/pure-runtime-highwater-v1674"
v1673="$kit/tests/validation/pure-runtime-reclaim-v1673"
work=${V1678_WORK_DIR:-$(mktemp -d "$TMPDIR/daimos-v1678-physical-fault.XXXXXX")}
mkdir -p "$work"
for f in "$V1678_BUILD/kcore.map" \
         "$V1678_BUILD/pure-mres-v1612.map" \
         "$V1678_BUILD/pure-mres-v1612.dxr" \
         "$V1678_BUILD/boot.ini" \
         "$V1678_FIXTURE/v1673-test-init.map"; do
    test -s "$f" || { echo "Missing v1678 source file: $f" >&2; exit 1; }
done
grep -q '^v1678_rebase_fault_count[[:space:]]' \
    "$V1678_BUILD/pure-mres-v1612.map" || {
    echo 'FAIL v1678: PURE test-only fault counter absent' >&2
    exit 1
}
V1678_PURE_MAP="$V1678_BUILD/pure-mres-v1612.map" \
V1673_ONLY_VARIANT="$V1678_VARIANT" \
V1673_WORK_DIR="$work" \
V1673_GENERAL_BUILD="$V1678_BUILD" \
V1673_STRICT_BUILD="$V1678_BUILD" \
V1673_FIXTURE_BUILD="$V1678_FIXTURE" \
V1673_GUEST_C="$v1674/proc-pressure-v1674.c" \
V1673_CHILD_ASM="$v1674/pipe-child-v1674.s" \
V1673_CTY_DRIVER="$here/host-cty-fault-v1678.py" \
V1673_TIMEOUT=${V1673_TIMEOUT:-3600} \
KEEP_TEST=1 sh "$v1673/run-physical-v1673.sh"
variant=$V1678_VARIANT
python3 "$here/verify-fault-v1678.py" \
    "$work/$variant-48-console.clean" "$V1678_BUILD/kcore.map" \
    "$V1678_BUILD/pure-mres-v1612.map"
python3 "$here/test-fault-negative-v1678.py" \
    "$work/$variant-48-console.clean" "$V1678_BUILD/kcore.map" \
    "$V1678_BUILD/pure-mres-v1612.map" "$work/unsafe-witness-v1678"
if [ "${V1678_FAST:-0}" = 1 ]; then
    echo "PASS v1678: $variant physical A/B/C and real MRES fault witness"
    echo "v1678 scoped no-write-watch evidence: $work"
    echo 'NOT ACCEPTED: continuous physical MM writes and full PI6 fault matrix'
    exit 0
fi
python3 "$v1674/trace-v1674.py" \
    "$V1678_FIXTURE/v1673-test-init.map" "$V1678_BUILD/kcore.map" \
    "$work/$variant-48-console.clean" \
    "$work/$variant-48-report.json" \
    "$work/$variant-48-highwater.json"
KEEP_TEST=1 sh "$v1674/run-negative-v1674.sh" \
    "$work/$variant-48-console.clean" \
    "$V1678_FIXTURE/v1673-test-init.map" "$V1678_BUILD/kcore.map" \
    "$work/$variant-48-report.json" \
    "$work/$variant-48-highwater.json"
echo "PASS v1678: $variant real 48K physical fault-injected RAW PURE"
echo "v1678 evidence: $work"
echo 'NOT YET ACCEPTED: paired general/strict and actual MM fault recovery remain separate gates'
