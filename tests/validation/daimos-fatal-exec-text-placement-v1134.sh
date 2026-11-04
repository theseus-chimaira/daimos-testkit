#!/bin/sh
# Diagnostic only: unused text before RUN rollback, no executed new code.
# Do not transplant placement padding into production as a workaround.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1126_NESTED=1 DAIMOS_V1134_TEXT_PLACEMENT=1 \
    sh "$self/daimos-fatal-exec-integration-v890.sh"
