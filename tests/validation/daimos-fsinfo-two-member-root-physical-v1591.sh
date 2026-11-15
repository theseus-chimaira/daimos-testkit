#!/bin/sh
# Boot genuine TSFS DTC0/1 two-member root: eight KINIT/FSINFO slots.
# Four independently stamped DTFS mounts exercise high IDs and holes.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export DAIMOS_TSFS_GATE_TWO_MEMBER_ROOT_V1591=1
export DAIMOS_TSFS_GATE_FSINFO_HI_V1533=1
export DAIMOS_TSFS_GATE_SOURCE_V1526=\
"$self/../target/daimos-fsinfo-two-member-root-physical-v1591.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526="FSINFOINV V1591"
export DAIMOS_TSFS_GATE_STAGES_V1526=\
"START CAPACITY8 MOUNTED5 HOLE_STABLE RETIRED PASS"
exec sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
