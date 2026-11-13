#!/bin/sh
# Boot real 256K PDP-6 TSFS-root KCORE, enumerate the runtime mount slab.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export DAIMOS_TSFS_GATE_SOURCE_V1526=\
"$self/../target/daimos-fsinfo-capacity-physical-v1532.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526="FSINFOCAP V1532"
export DAIMOS_TSFS_GATE_STAGES_V1526=\
"START CAPACITY7 SCANNED7 RETIRED PASS"
exec sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
