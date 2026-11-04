#!/bin/sh
# v1109: VM destroy integrated with real MEMFS XIP provider and MM pin.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1109_XIP_VM=1 sh "$self/daimos-slot0-memfs-pi6-v1086.sh"
