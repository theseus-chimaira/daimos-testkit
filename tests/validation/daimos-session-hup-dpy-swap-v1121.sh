#!/bin/sh
# v1121: Type-340 MM_BUSY during real DISK swap-out/restore lifecycle.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1105_DPY_HUP=1 DAIMOS_V1107_SWAP_HUP=1 \
    sh "$self/daimos-session-hup-physical-v907.sh"
