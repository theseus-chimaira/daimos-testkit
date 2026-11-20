#!/bin/sh
# K01 physical-guest acceptance: persistent MM owner refusals.
# Reuses the full-system v909/v1101/v1125 PDP-6 guest and its assertions.
# Only the guest's copied kernel is fault-injected; production is unchanged.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

case ${K01_PHYSICAL_CASE:-all} in
all) cases='busy invalid foreign' ;;
busy|invalid|foreign) cases=${K01_PHYSICAL_CASE} ;;
*) echo 'v1703: K01_PHYSICAL_CASE must be all, busy, invalid or foreign' >&2
   exit 2 ;;
esac

test -x "$PDP10_PREFIX/bin/pdp6" || {
    echo 'v1703: physical PDP-6 simulator missing' >&2
    exit 2
}
test -f "$self/daimos-fatal-mm-persistent-v909.sh" || {
    echo 'v1703: v909 physical MM fault injector missing' >&2
    exit 2
}
test -f "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" || {
    echo 'v1703: production MM source missing' >&2
    exit 2
}

source_rev=$(git -C "$DAIMOS_REPO" rev-parse HEAD)
testkit_rev=$(git -C "$self/../.." rev-parse HEAD)
printf 'v1703: DAIMOS=%s testkit=%s\n' "$source_rev" "$testkit_rev"
printf 'v1703: physical cases=%s\n' "$cases"

# Preparation reports case selection only. It never signals acceptance.
if [ "${K01_PHYSICAL_PREPARE_ONLY:-0}" = 1 ]; then
    echo 'v1703: PREPARED ONLY (no guest boot or acceptance)'
    exit 0
fi

work=$(mktemp -d "$TMPDIR/daimos-k01-physical-owner-gate-v1703.XXXXXX")
printf '%s\n' "$source_rev" > "$work/daimos-revision"
printf '%s\n' "$testkit_rev" > "$work/testkit-revision"
echo "v1703: evidence directory=$work"

for name in $cases; do
    case $name in
    busy)
        mode=pin
        foreign=0
        witness='v909: permanent actual-MM pin, capped idle-reaper'
        ;;
    invalid)
        mode=wrong-owner
        foreign=0
        witness='v1101: permanent MM wrong owner (-4)'
        ;;
    foreign)
        mode=wrong-owner
        foreign=1
        witness='v1125: real wrong-owner MM -4 and distinct held FS lease'
        ;;
    esac

    printf 'v1703: START %s mode=%s foreign=%s\n' \
        "$name" "$mode" "$foreign"
    if DAIMOS_V1101_MM_MODE="$mode" DAIMOS_V1125_FOREIGN="$foreign" \
        KEEP_TEST=1 sh "$self/daimos-fatal-mm-persistent-v909.sh" \
        > "$work/$name.log" 2>&1; then
        if grep -Fq "$witness" "$work/$name.log"; then
            printf 'PASS %s\n' "$name" >> "$work/results"
            echo "v1703: PASS $name"
            continue
        fi
        echo "v1703: missing physical witness: $name" >&2
    else
        echo "v1703: full-guest failure: $name" >&2
    fi
    printf 'FAIL %s\n' "$name" >> "$work/results"
    tail -70 "$work/$name.log" >&2
    echo "v1703: evidence directory=$work" >&2
    exit 1
done

echo 'v1703: all selected full-guest MM owner-refusal cases PASS'
echo "v1703: evidence directory=$work"
