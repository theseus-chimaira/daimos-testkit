#!/bin/sh
# E07: held FS provider plus physical PIPE/DPY/VM/u-area faults, PI6.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1103_MULTISTAGE=1 DAIMOS_V1106_PHYSICAL_VM=1 \
    DAIMOS_V1117_WAIT_CHURN=1 DAIMOS_V1144_DPY_MIXED=1 \
    DAIMOS_V1153_PI6_SPINNERS=1 \
    sh "$self/daimos-oom-pre-vm-retry-v997.sh"
