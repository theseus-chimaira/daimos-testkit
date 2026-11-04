#!/bin/sh
# Diagnostic only: instrument real unpublished RUN rollback after APR/EXEC.
# A completed snapshot is NOT an OOM D13 acceptance test.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1126_NESTED=1 DAIMOS_V1131_DISCARD_TRACE=1 \
    sh "$self/daimos-fatal-exec-integration-v890.sh"
