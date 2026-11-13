#!/bin/sh
# Actual Type-551 DTC3 write interrupted after one modified physical word.
# Requires full-platform build of the diagnostic simulator pdp6-v1529r5.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
: "${PDP10_PREFIX:?PDP10_PREFIX required}"
test -x "$PDP10_PREFIX/bin/pdp6-v1529r5" || {
    echo 'v1529: missing test-only PDP-6 simulator' >&2
    exit 1
}
export DAIMOS_TSFS_SIMH="$PDP10_PREFIX/bin/pdp6-v1529r5"
export DAIMOS_TSFS_GATE_PARTIAL_V1529=1
export DAIMOS_TSFS_GATE_SOURCE_V1526=\
"$self/../target/daimos-dtfs-partial-write-v1529.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526="DTFSPART V1529"
export DAIMOS_TSFS_GATE_STAGES_V1526=\
"START READY_ARM WRITE_FAILED READY_VERIFY STICKY_CONFIRMED PASS"
exec sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
