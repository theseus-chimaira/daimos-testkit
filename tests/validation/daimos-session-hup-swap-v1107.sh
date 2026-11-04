#!/bin/sh
# v1107: real DISK swap backing bitmap refusal during session HUP.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1107_SWAP_HUP=1 sh "$self/daimos-session-hup-physical-v907.sh"
