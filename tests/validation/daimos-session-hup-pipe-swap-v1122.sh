#!/bin/sh
# v1122: real first-member PIPE MM_BUSY and second-member DISK bitmap.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1104_PIPE_HUP=1 DAIMOS_V1107_SWAP_HUP=1 \
    sh "$self/daimos-session-hup-physical-v907.sh"
