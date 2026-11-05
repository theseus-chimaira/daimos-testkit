#!/bin/sh
# E05/E06: sustained real physical OOM and full owner accounting.
# The production OOM switch stays off; enabled mode uses a copy only.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
V1151_TEST_ENDURANCE=1 V1120_TEST_PID_REUSE=1 \
    V1075_TEST_OOM_ENABLED=${V1151_OOM_ENABLED:-1} \
    sh "$self/daimos-oom-requester-live-v1075.sh"
