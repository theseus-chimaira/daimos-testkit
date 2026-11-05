#!/bin/sh
# E10: APR and postcommit EXEC/RUN while another FS owner holds its lease.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1126_NESTED=1 DAIMOS_V1142_PHYSICAL_UAREA=1 \
    DAIMOS_V1157_PROVIDER=1 \
    sh "$self/daimos-fatal-exec-integration-v890.sh"
