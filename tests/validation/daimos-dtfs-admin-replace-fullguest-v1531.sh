#!/bin/sh
# Root-only owner-checked, DIFFERENT 72-bit replacement of a poisoned DTC3.
# The test must reject an identical original medium even when unowned.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export DAIMOS_TSFS_GATE_ADMIN_V1531=1
export DAIMOS_TSFS_GATE_SYSCALL_V1531=1
export DAIMOS_TSFS_GATE_SOURCE_V1526=\
"$self/../target/daimos-dtfs-admin-replace-v1531.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526="DTFSADMIN V1531"
export DAIMOS_TSFS_GATE_STAGES_V1526=\
"START READY_DETACH WRITE_FAILED READY_RETURN SAME_REJECTED READY_REPLACE RETIRED PASS"
exec sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
