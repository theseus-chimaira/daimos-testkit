#!/bin/sh
# v1571: NEGATIVE physical Type-551 reel-generation proof.
# Two distinct valid CLEAN V2 images are exchanged only while the
# real PID1 blocks on CTY; no DTC read error precedes subsequent I/O.
# The unchanged production kernel is deliberately expected to remain
# blind to this unsafe, out-of-band replacement. This does NOT enable RW.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export DAIMOS_TSFS_SIMH="${DAIMOS_TSFS_SIMH:-$PDP10_PREFIX/bin/pdp6}"
export DAIMOS_TSFS_GATE_DTVOL2_V1564=1
export DAIMOS_TSFS_GATE_SILENT_SWAP_V1571=1
export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-v2-silent-exchange-v1571.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526='V2EXCHANGE V1571'
export DAIMOS_TSFS_GATE_STAGES_V1526='START READY_SWAP BLIND_SPOT_CONFIRMED PASS_NEGATIVE'
exec sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
