#!/bin/sh
# v1119: combined actual PIPE and Type-340 DPY MM_BUSY on session HUP.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1104_PIPE_HUP=1 DAIMOS_V1105_DPY_HUP=1 \
    sh "$self/daimos-session-hup-physical-v907.sh"
