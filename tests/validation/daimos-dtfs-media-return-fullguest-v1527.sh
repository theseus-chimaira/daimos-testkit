#!/bin/sh
# Real Type-551 physical DTC3 detach, replacement and verified 72-bit
# same-media return with original live FILE; independent DTC4 remains good.
# The existing v1525 full-guest boot harness supplies the KCORE and
# physically transports the test's SIMH control commands.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export DAIMOS_TSFS_GATE_MEDIA_V1527=1
export DAIMOS_TSFS_GATE_SOURCE_V1526=\
"$self/../target/daimos-dtfs-media-return-v1527.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526="DTFSMEDIA V1527"
export DAIMOS_TSFS_GATE_STAGES_V1526=\
"START READY_DETACH OFFLINE_REFUSED READY_SWAP REPLACEMENT_REFUSED READY_RESTORE RETURN_VERIFIED PASS"
exec sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
