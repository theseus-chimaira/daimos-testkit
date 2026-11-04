#!/bin/sh
# v1118: one boot combines real PIPE and process-VM MM_BUSY, FILE and
# HUP refusals, final u-area retry, held foreign FS lease, and stale
# WAIT/PID plus independent runnable-process checks.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1103_MULTISTAGE=1 DAIMOS_V1106_PHYSICAL_VM=1 \
    DAIMOS_V1117_WAIT_CHURN=1 \
    sh "$self/daimos-oom-pre-vm-retry-v997.sh"
