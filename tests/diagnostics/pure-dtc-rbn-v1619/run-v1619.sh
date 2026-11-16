#!/bin/sh
# Physical read-only PDP-6 DECtape DTC0 RBN target-4 fixture on an
# actual generated TSFS root tape; check near and long-reverse reads.
# This is diagnostic, not complete PURE restore acceptance.
set -eu
: "${DAIMOS_REPO:?DAIMOS checkout required}"
: "${PURE_DTC_BUILD_V1618:?matching real 48K TSFS image required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../.." && pwd)
work=$(mktemp -d "$TMPDIR/dtc-rbn-v1619.XXXXXX")
keep=${KEEP_TEST:-0}
cleanup()
{
    if [ "$keep" = 1 ]; then
        echo "v1619: retained physical RBN evidence $work"
    else
        rm -rf "$work"
    fi
}
trap cleanup EXIT HUP INT TERM

source="$PURE_DTC_BUILD_V1618/media/dtc0.tap"
test -s "$source"
cp "$source" "$work/dtc0.tap"
cat >"$work/dtc.ini" <<EOF
set DCT enabled
set DTC enabled
set DTC0 enabled
set DTC DCT=4
attach -q DTC0 $work/dtc0.tap
EOF

for scenario in near reverse; do
    if [ "$scenario" = near ]; then
        sed 's/\\.set FIRST_BLOCK,0341/.set FIRST_BLOCK,000004/' \
            "$here/read-block-v1619.s" >"$work/test-$scenario.s"
    else
        cp "$here/read-block-v1619.s" "$work/test-$scenario.s"
    fi
    echo "v1619: real DTC0 TSFS RBN target 4, case=$scenario"
    if ! "$PDP10_PREFIX/bin/p10run" \
        --machine pdp6 --mode deposit --exec-mode go \
        --start 1000 --timeout "${PURE_RBN_TIMEOUT_V1619:-180}" \
        --workdir "$work/run-$scenario" --name "dtc-rbn-$scenario-v1619" \
        --ini "$work/dtc.ini" --expect __test_exit=0 \
        "$kit/validation/daimos-test-crt0-v1.s" \
        "$work/test-$scenario.s" \
        "$DAIMOS_REPO/system/kernel/drivers/tape_io.s" \
        "$DAIMOS_REPO/system/kernel/storage/storage_router.s" \
        "$kit/validation/daimos-dtc-stream-online-stubs-v1.s" \
        >"$work/$scenario.log" 2>&1; then
        tail -62 "$work/$scenario.log" >&2
        echo "v1619: UNRESOLVED physical $scenario DTC0 block read" >&2
        keep=1
        exit 1
    fi
    if ! cmp -s "$source" "$work/dtc0.tap"; then
        echo "FAIL v1619: physical DTC0 read-only diagnostic changed TSFS tape" >&2
        keep=1
        exit 1
    fi
    echo "PASS v1619: physical DTC0 $scenario block 4 RBN and data"
done
echo 'PASS v1619: all tested read-only tape media remain byte-identical'
