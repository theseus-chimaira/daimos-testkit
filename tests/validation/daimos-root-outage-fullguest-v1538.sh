#!/bin/sh
# Full actual PDP-6 selected TSFS root failure: all root members detached.
# Does not classify unplug by controller status, exercises real root I/O.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export DAIMOS_TSFS_GATE_ROOTLOSS_V1538=1
export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-root-outage-physical-v1538.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526="ROOTLOSS V1538"
export DAIMOS_TSFS_GATE_STAGES_V1526="START READY_DETACH"
exec sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
