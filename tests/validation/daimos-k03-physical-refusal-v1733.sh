#!/bin/sh
# K03 physical 256K PDP-6: independent requester OOM and refusal witnesses.
# The original guest fixtures have incompatible fault-injection modes;
# run them separately, never claim a combined guest or bounded recovery.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-"$HOME/tmp"}
export TMPDIR V1283_PRODUCTION_OOM_DEFAULT=1
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-k03-physical-v1733.XXXXXX")
printf 'DAIMOS_HEAD %s\n' "$(git -C "$DAIMOS_REPO" rev-parse HEAD)" > "$work/results"
printf 'TESTKIT_HEAD %s\n' "$(git -C "$self/../.." rev-parse HEAD)" >> "$work/results"
group=${1:-all}
case "$group" in
    runparent|held|permanent|all) ;;
    *) echo 'usage: daimos-k03-physical-refusal-v1733.sh [runparent|held|permanent|all]' >&2; exit 2 ;;
esac
run_gate()
{
    name=$1
    shift
    echo "v1733: starting $name"
    if "$@" > "$work/$name.log" 2>&1; then
        printf 'PASS %s\n' "$name" >> "$work/results"
        tail -5 "$work/$name.log"
    else
        code=$?
        printf 'FAIL %s %s\n' "$name" "$code" >> "$work/results"
        tail -60 "$work/$name.log" >&2
        echo "v1733: FAIL $name; evidence $work" >&2
        exit "$code"
    fi
}
if [ "$group" = runparent ] || [ "$group" = all ]; then
    run_gate runparent sh "$self/daimos-oom-run-parent-v1158.sh"
fi
if [ "$group" = held ] || [ "$group" = all ]; then
    run_gate held env V1150_TEST_HELD_PROVIDER=1 \
        sh "$self/daimos-oom-requester-live-v1075.sh"
fi
if [ "$group" = permanent ] || [ "$group" = all ]; then
    run_gate permanent sh "$self/daimos-fatal-mm-provider-v1125.sh"
fi
echo "v1733: $group physical gates PASS; independent fixtures, not one guest"
echo "v1733: evidence $work"
