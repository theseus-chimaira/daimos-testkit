#!/bin/sh
# v1108: real MEMFS XIP MM pin-state refusal and safe retry.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1108_XIP_MM=1 sh "$self/daimos-slot0-memfs-pi6-v1086.sh"
