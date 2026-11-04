#!/bin/sh
# v1142: real MM pin/BUSY/unpin in the nested unpublished RUN rollback.
# Only the disposable kernel receives the MM fault hook.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1126_NESTED=1 DAIMOS_V1142_PHYSICAL_UAREA=1 \
    sh "$self/daimos-fatal-exec-integration-v890.sh"
