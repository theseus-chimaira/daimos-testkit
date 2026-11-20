#!/bin/sh
# K01 integrated evidence gate, not a new disposable physical guest.
# The caller must provide actual completed F07 and native evidence.
set -eu
: "${DAIMOS_REPO:?}" "${K01_CLEAN_GUEST:?}" "${K01_FAULT_GUEST:?}"
: "${K01_NATIVE_EVIDENCE:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-k01-integrated-v1717.XXXXXX")
echo "K01 v1717: integrated evidence=$work"
git -C "$DAIMOS_REPO" rev-parse HEAD > "$work/daimos-revision"
git -C "$self/../.." rev-parse HEAD > "$work/testkit-revision"

for name in clean fault; do
    case $name in
    clean) guest=$K01_CLEAN_GUEST ;;
    fault) guest=$K01_FAULT_GUEST ;;
    esac
    test -s "$guest/addresses" && test -s "$guest/simh.out" || {
        echo "K01 v1717: missing completed $name guest" >&2
        exit 1
    }
    sha256sum "$guest/addresses" "$guest/simh.out" >> "$work/guest-sha256"
done

run()
{
    label=$1
    shift
    echo "K01 v1717: $label"
    if "$@" > "$work/$label.log" 2>&1; then
        printf 'PASS %s\n' "$label" >> "$work/results"
        tail -4 "$work/$label.log"
    else
        printf 'FAIL %s\n' "$label" >> "$work/results"
        tail -55 "$work/$label.log" >&2
        echo "K01 v1717: FAILED evidence=$work" >&2
        exit 1
    fi
}

# Require the unmodified *clean* v1336/v1349 F07 postflight, including
# real no-partner pressure and independent owner release.
run clean-v1336 python3 \
    "$self/daimos-swap-independent-release-verify-v1336.py" \
    "$K01_CLEAN_GUEST/addresses" "$K01_CLEAN_GUEST/simh.out"
run clean-v1303 python3 \
    "$self/daimos-swap-no-partner-physical-v1303.py" \
    "$K01_CLEAN_GUEST/addresses" "$K01_CLEAN_GUEST/simh.out"
run clean-v1349 python3 \
    "$self/daimos-swap-owner-lifecycle-v1349.py" \
    "$K01_CLEAN_GUEST/addresses" "$K01_CLEAN_GUEST/simh.out" \
    "$K01_CLEAN_GUEST/simh-sampler.log"

# The intentionally faulted guest has a separate strict verifier.
# The original clean verifier is never weakened to permit fatal faults.
run fault-v1713 python3 "$self/daimos-k01-f07-faulted-verify-v1713.py" \
    "$K01_FAULT_GUEST/addresses" "$K01_FAULT_GUEST/simh.out"

# A native result list must be complete and must have been run against
# the identical production kernel source. Later documentation commits
# do not invalidate it, but kernel changes require a new native run.
native=$K01_NATIVE_EVIDENCE
test -s "$native/results" && test -s "$native/daimos-revision" || {
    echo 'K01 v1717: missing native acceptance revisions/results' >&2
    exit 1
}
source_rev=$(cat "$native/daimos-revision")
git -C "$DAIMOS_REPO" merge-base --is-ancestor "$source_rev" HEAD
if ! git -C "$DAIMOS_REPO" diff --quiet "$source_rev" HEAD -- system/kernel; then
    echo 'K01 v1717: production kernel changed since native acceptance' >&2
    exit 1
fi
# The native and guest builds use the working checkout, not only HEAD.
# Do not certify evidence against uncommitted assembler/C/header edits.
if git -C "$DAIMOS_REPO" status --porcelain -- system/kernel | \
        grep -E '\.(s|c|h|inc)$' > /dev/null; then
    echo 'K01 v1717: uncommitted production kernel source changed' >&2
    exit 1
fi
if [ "$(wc -l < "$native/results")" -ne 33 ] || \
   [ "$(grep -c '^PASS ' "$native/results")" -ne 33 ] || \
   [ "$(sort -u "$native/results" | wc -l)" -ne 33 ]; then
    echo 'K01 v1717: native evidence is incomplete or duplicated' >&2
    exit 1
fi
cp "$native/results" "$work/native-results"
printf 'PASS native-33\n' >> "$work/results"
echo 'K01 v1717: 33 source-linked PDP-6 native cases PASS'

run source-v1716 python3 \
    "$self/daimos-k01-mm-free-site-audit-v1716.py" "$DAIMOS_REPO"
echo 'K01 v1717: clean, faulted, native and source acceptance PASS'
echo 'K01 v1717: permanent-refusal v1703 and PI6 v1704 remain separately documented'
echo "K01 v1717: evidence=$work"
