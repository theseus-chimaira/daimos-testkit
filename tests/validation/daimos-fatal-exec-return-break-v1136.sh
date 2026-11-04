#!/bin/sh
# Test-only SIMH breakpoints: child rollback entry and RUN epilogue.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1126_NESTED=1 DAIMOS_V1136_BREAK_TRACE=1 \
    sh "$self/daimos-fatal-exec-integration-v890.sh"
