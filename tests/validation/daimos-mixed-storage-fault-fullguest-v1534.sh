#!/bin/sh
# Physical Type-551 DTC3 write failure, independent DTC4, MEMFS, TSFS.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export DAIMOS_TSFS_GATE_MIXED_V1534=1
export DAIMOS_TSFS_GATE_SOURCE_V1526=\
"$self/../target/daimos-mixed-storage-fault-v1534.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526="MIXEDIO V1534"
export DAIMOS_TSFS_GATE_STAGES_V1526=\
"START READY_DETACH WRITE_FAILED HEALTHY_DURING READY_RETURN HEALTHY_RETURN RETIRED_HEALTHY PASS"
exec sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
