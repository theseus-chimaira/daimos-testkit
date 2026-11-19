#!/bin/sh
# v1677 physical 48K MRES lost-success reply test; KCORE is unchanged.
# Run one profile at a time with a source-linked injected MRES build.
set -eu
: "${DAIMOS_REPO:?source-matched PURE checkout required}"
: "${V1677_VARIANT:?select general or strict}"
: "${V1677_BUILD:?absolute source-built injected image directory}"
: "${V1677_FIXTURE:?exact deterministic pipe fixture directory}"
case "$V1677_VARIANT" in general|strict) ;; *) exit 2 ;; esac
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
v1674="$kit/tests/validation/pure-runtime-highwater-v1674"
v1673="$kit/tests/validation/pure-runtime-reclaim-v1673"
work=${V1677_WORK_DIR:-$(mktemp -d "$TMPDIR/daimos-v1677-physical-fault.XXXXXX")}
mkdir -p "$work"
for f in "$V1677_BUILD/kcore.map" \
         "$V1677_BUILD/pure-mres-v1612.map" \
         "$V1677_BUILD/pure-mres-v1612.dxr" \
         "$V1677_BUILD/boot.ini" \
         "$V1677_FIXTURE/v1673-test-init.map"; do
    test -s "$f" || { echo "Missing v1677 source file: $f" >&2; exit 1; }
done
grep -q '^v1677_fault_return_count[[:space:]]' \
    "$V1677_BUILD/pure-mres-v1612.map" || {
    echo 'FAIL v1677: PURE test-only fault counter absent' >&2
    exit 1
}
V1677_PURE_MAP="$V1677_BUILD/pure-mres-v1612.map" \
V1673_ONLY_VARIANT="$V1677_VARIANT" \
V1673_WORK_DIR="$work" \
V1673_GENERAL_BUILD="$V1677_BUILD" \
V1673_STRICT_BUILD="$V1677_BUILD" \
V1673_FIXTURE_BUILD="$V1677_FIXTURE" \
V1673_GUEST_C="$v1674/proc-pressure-v1674.c" \
V1673_CHILD_ASM="$v1674/pipe-child-v1674.s" \
V1673_CTY_DRIVER="$here/host-cty-fault-v1677.py" \
V1673_TIMEOUT=${V1673_TIMEOUT:-3600} \
KEEP_TEST=1 sh "$v1673/run-physical-v1673.sh"
variant=$V1677_VARIANT
python3 "$v1674/trace-v1674.py" \
    "$V1677_FIXTURE/v1673-test-init.map" "$V1677_BUILD/kcore.map" \
    "$work/$variant-48-console.clean" \
    "$work/$variant-48-report.json" \
    "$work/$variant-48-highwater.json"
KEEP_TEST=1 sh "$v1674/run-negative-v1674.sh" \
    "$work/$variant-48-console.clean" \
    "$V1677_FIXTURE/v1673-test-init.map" "$V1677_BUILD/kcore.map" \
    "$work/$variant-48-report.json" \
    "$work/$variant-48-highwater.json"
echo "PASS v1677: $variant real 48K physical fault-injected RAW PURE"
echo "v1677 evidence: $work"
echo 'NOT YET ACCEPTED: paired general/strict and actual MM fault recovery remain separate gates'
