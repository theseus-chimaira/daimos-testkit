#!/bin/sh
# Diagnostic only: compare real idle timer/PI state at two iteration counts.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1126_DIAG=1 DAIMOS_V1127_DUAL_TIMER=1 \
    sh "$self/daimos-fatal-exec-integration-v890.sh"
