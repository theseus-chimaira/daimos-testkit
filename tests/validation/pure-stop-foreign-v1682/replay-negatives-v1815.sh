#!/bin/sh
# Recheck immutable, original v1682 physical evidence and ten mutated
# witnesses. This does not boot a new guest or certify current kernels.
set -eu
: "${V1815_EVIDENCE_ROOT:?set preserved v1682 physical evidence root}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
root=$V1815_EVIDENCE_ROOT
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work=$(mktemp -d "$TMPDIR/pure-stop-replay-v1815.XXXXXX")
cleanup()
{
    rc=$?
    if test "$rc" -eq 0 && test "${KEEP_WORK:-0}" != 1; then
        rm -rf "$work"
    else
        echo "v1815 evidence outputs retained at $work" >&2
    fi
}
trap cleanup EXIT

# The same v1673 test-init fixture was used for GENERAL and STRICT.
fixture="$root/guest-general/fixture/v1673-test-init.map"
test -s "$fixture"
for variant in general strict; do
    core="$root/guest-$variant/$variant-build/kcore.map"
    trace="$root/guest-$variant/$variant-48-console.clean"
    test -s "$core" && test -s "$trace"
    echo "v1815: original physical source check ($variant)"
    python3 "$here/measure-v1682.py" \
        "$fixture" "$core" "$trace" 48 "$work/$variant-accepted.json"
    echo "v1815: five genuine physical source mutations ($variant)"
    python3 "$here/test-negative-v1682.py" \
        "$fixture" "$core" "$trace" "$variant" "$work/$variant-negative"
done
echo 'PASS v1815: 2 historical original source replays and 10 negative controls'
