#!/bin/sh
# Diagnostic only: two minimal counters in the real late RUN rollback.
# A completed snapshot is NOT an OOM D13 acceptance test.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1126_NESTED=1 DAIMOS_V1133_RUN_ONLY=1 \
    sh "$self/daimos-fatal-exec-integration-v890.sh"
