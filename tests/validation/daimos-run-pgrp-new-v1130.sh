#!/bin/sh
# D13 isolation: identical late RUN rollback, but NEW process groups.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
DAIMOS_RUN_PGRP_NEW_V1130=1 \
    sh "$self/daimos-run-late-rollback-v197.sh"
