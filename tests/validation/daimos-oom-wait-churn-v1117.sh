#!/bin/sh
# Full guest mixed fatal teardown then 48 stale WAIT/PID/event probes.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1103_MULTISTAGE=1 DAIMOS_V1117_WAIT_CHURN=1 \
 sh "$self/daimos-oom-pre-vm-retry-v997.sh"
