#!/bin/sh
# Diagnostic: additional post-VM release breakpoints, no kernel mutation.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1126_NESTED=1 DAIMOS_V1138_DISCARD_BREAKS=1 \
    DAIMOS_V1139_RELEASE_BREAKS=1 \
    sh "$self/daimos-fatal-exec-integration-v890.sh"
