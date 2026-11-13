#!/bin/sh
# Full PDP-6 TSFS root; four separately stamped physical DTC3..DTC6 mounts.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export DAIMOS_TSFS_GATE_FSINFO_HI_V1533=1
export DAIMOS_TSFS_GATE_SOURCE_V1526=\
"$self/../target/daimos-fsinfo-high-mount-physical-v1533.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526="FSINFOHI V1533"
export DAIMOS_TSFS_GATE_STAGES_V1526=\
"START MOUNTED5 SCANNED7 HOLE_STABLE RETIRED PASS"
exec sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
