#!/bin/sh
# Real Type-551 DTC3 write failure under a RW DTFS mount, followed by
# exactly matching stamped media return with sticky refusal.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export DAIMOS_TSFS_GATE_WRITE_V1528=1
export DAIMOS_TSFS_GATE_SOURCE_V1526=\
"$self/../target/daimos-dtfs-write-uncertain-v1528.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526="DTFSWRITE V1528"
export DAIMOS_TSFS_GATE_STAGES_V1526=\
"START READY_DETACH WRITE_FAILED READY_RESTORE WRITE_STICKY PASS"
exec sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
