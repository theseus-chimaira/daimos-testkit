#!/bin/sh
# v1807: verify TWO independently executed 48K PURE physical guests.
# Accept no synthetic reports or historical-source resident baseline.
set -eu
: "${DAIMOS_REPO:?DAIMOS integration source worktree required}"
if [ "$#" -ne 1 ]; then
    echo 'usage: check-physical-pair-v1807.sh PHYSICAL_EVIDENCE_DIRECTORY' >&2
    exit 2
fi
work=$1
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
base="$testkit/tests/validation/pure-runtime-reclaim-v1673"
for variant in general strict; do
    for suffix in 48-console.clean 48-report.json; do
        test -s "$work/$variant-$suffix"
    done
    test -s "$work/$variant-build/kcore.map"
    test -s "$work/$variant-build/kinit.map"
    test -s "$work/$variant-48-noaux.ini"
    grep -Fq "$work/$variant-48-media/" "$work/$variant-48-noaux.ini"
    for gate in A B C; do
        grep -Fxq "V1673 HOLD $gate" "$work/$variant-48-console.clean"
        grep -Fq "V1673 RELEASE $gate" "$work/$variant-48-console.clean"
    done
    grep -Fq 'V1673 PASS RUN EXIT WAIT' \
        "$work/$variant-48-console.clean"
    grep -q '^proc_pure_mres_package_v1612[[:space:]]' \
        "$work/$variant-build/kinit.map"
done
# Paired transcripts must come from separate simulator sessions.
# Identical byte-for-byte captures are not independent evidence.
set +e
cmp -s "$work/general-48-console.clean" "$work/strict-48-console.clean"
cmp_rc=$?
set -e
case "$cmp_rc" in
    1) : ;;
    0) echo 'FAIL v1807: duplicated guest transcript' >&2; exit 1 ;;
    *) echo 'FAIL v1807: cannot compare guest transcripts' >&2; exit 1 ;;
esac
# Strict swapless has no disk SWAP service; GENERAL intentionally does.
grep -q '^proc_swap_mres_package_v481[[:space:]]' \
    "$work/general-build/kinit.map"
if grep -q '^proc_swap_mres_package_v481[[:space:]]' \
    "$work/strict-build/kinit.map"; then
    echo 'FAIL v1807: STRICT guest linked disk SWAP service' >&2
    exit 1
fi
export V1673_SOURCE_PROFILE_V1807=integration
python3 "$base/compare-v1673.py" \
    "$work/general-48-report.json" \
    "$work/strict-48-report.json"
# Recheck original physical words and mutation controls against each map.
for variant in general strict; do
    sh "$base/run-negative-v1673.sh" \
        "$work/$variant-48-console.clean" \
        "$work/fixture/v1673-test-init.map" \
        "$work/$variant-build/kcore.map" \
        "$work/$variant-48-report.json"
done
echo 'PASS v1807: independent GENERAL/STRICT 48K RAW PURE owners/WAIT + negative controls'
