#!/bin/sh
# v1105: real two-member HUP with pinned DPY/PI6 raw list and u-area.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1105_DPY_HUP=1 sh "$self/daimos-session-hup-physical-v907.sh"
