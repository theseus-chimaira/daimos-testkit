#!/bin/sh
# D13 diagnostic: no kernel instrumentation; sample real UUO/stack state.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1126_NESTED=1 DAIMOS_V1135_RETURN_SNAPSHOT=1 \
    sh "$self/daimos-fatal-exec-integration-v890.sh"
