#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-dtc-reverse-online-v1-$$"
media="$work/dtc0.tap"
debug="$work/dtc.debug"
ini="$work/dtc.ini"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

cat > "$ini" <<EOF2
set DCT enabled
set DTC enabled
set DTC0 enabled
set DTC DCT=4
attach -q -n DTC0 $media
set debug $debug
set DTC debug=DETAIL
EOF2

PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
    --start 1000 --timeout 30 --workdir "$work/run" --name daimos-dtc-reverse \
    --ini "$ini" --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$self/daimos-dtc-reverse-online-v1.s" \
    "$DAIMOS_REPO/system/kernel/drivers/tape_io.s" \
    "$DAIMOS_REPO/system/kernel/storage/storage_router.s" \
    "$self/daimos-dtc-stream-online-stubs-v1.s" >/dev/null

# This is not merely a data-integrity test.  The simulator trace must prove
# that the production driver actually transferred data while the transport was
# moving backward.  A force-forward workaround would therefore fail here even
# though its final buffer contents might happen to be correct.
reverse_words=$(grep -c 'rev data word' "$debug" || true)
if [ "$reverse_words" -lt 128 ]; then
    echo "dtc-reverse-online: expected reverse data transfer, saw $reverse_words words" >&2
    exit 1
fi

printf '%s\n' 'dtc-reverse-online: PASS (production single-block reverse read/write)'
