#!/bin/sh
# Diagnostic only: test unchanged nested APR/EXEC/RUN code with 13 BSS words.
# This cannot certify D13 or justify production padding.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1126_NESTED=1 DAIMOS_V1132_LAYOUT_ONLY=1 \
    sh "$self/daimos-fatal-exec-integration-v890.sh"
