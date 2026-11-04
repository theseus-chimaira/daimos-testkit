#!/bin/sh
# D13 partial: boot APR, post-commit EXEC/FILE retry and late RUN rollback.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1126_NESTED=1 sh "$self/daimos-fatal-exec-integration-v890.sh"
