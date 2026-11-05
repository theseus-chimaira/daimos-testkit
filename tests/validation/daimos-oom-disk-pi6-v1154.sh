#!/bin/sh
# E07: independent user and real PI6 across disk-bitmap refusal/retry.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1104_PIPE_HUP=1 DAIMOS_V1107_SWAP_HUP=1 \
    DAIMOS_V1154_PI6_DISK_SPIN=1 \
    sh "$self/daimos-session-hup-physical-v907.sh"
