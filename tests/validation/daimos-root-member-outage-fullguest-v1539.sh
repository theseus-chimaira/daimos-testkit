#!/bin/sh
# Physical PDP-6: lose DTC0, just one of three active TSFS root members.
# Reuse the real v1538 root file-data oracle and exact KCORE root-HALT PC.
set -eu
export DAIMOS_TSFS_GATE_ONE_ROOTLOSS_V1539=1
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
exec sh "$self/daimos-root-outage-fullguest-v1538.sh"
