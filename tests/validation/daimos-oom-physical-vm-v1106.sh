#!/bin/sh
# P0-D: actual process VM extent -5 with held FS and u-area retry.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1106_PHYSICAL_VM=1 sh "$self/daimos-oom-pre-vm-retry-v997.sh"
