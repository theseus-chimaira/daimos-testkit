#!/bin/sh
# v1104: real two-member HUP with pinned PIPE final-close and u-area.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1104_PIPE_HUP=1 sh "$self/daimos-session-hup-physical-v907.sh"
