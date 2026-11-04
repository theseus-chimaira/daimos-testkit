#!/bin/sh
# v1101: booted real MM wrong-owner extent must never be falsely freed.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1101_MM_MODE=wrong-owner \
    sh "$self/daimos-fatal-mm-persistent-v909.sh"
