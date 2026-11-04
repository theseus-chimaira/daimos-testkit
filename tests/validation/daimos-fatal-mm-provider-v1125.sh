#!/bin/sh
# D12: physical MM wrong-owner -4 with a distinct live FS lease owner.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1101_MM_MODE=wrong-owner DAIMOS_V1125_FOREIGN=1 \
    sh "$self/daimos-fatal-mm-persistent-v909.sh"
