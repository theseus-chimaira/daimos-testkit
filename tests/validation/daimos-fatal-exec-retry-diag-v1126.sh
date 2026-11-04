#!/bin/sh
# Diagnose legacy v890 fatal FILE retry with a bounded guest snapshot.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1126_DIAG=1 sh "$self/daimos-fatal-exec-integration-v890.sh"
