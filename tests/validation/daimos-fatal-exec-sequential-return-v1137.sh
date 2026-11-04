#!/bin/sh
# D13 diagnostic: stop on late rollback, then its own RUN return.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1126_NESTED=1 DAIMOS_V1137_SEQUENTIAL=1 \
    sh "$self/daimos-fatal-exec-integration-v890.sh"
