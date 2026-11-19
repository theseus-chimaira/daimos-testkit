#!/bin/sh
# Capture genuine 48K five-PACKED->WAIT MM snapshots with source-linked
# SIMH ECHO markers. Reuses the exact v1629 guest; no code rebuild.
set -eu
: "${PURE_PACKED_BUILD_V1629:?source-built v1629 48K image required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export PURE_MM_BUILD_V1628="$PURE_PACKED_BUILD_V1629"
export PURE_MM_PROFILE_V1629=48packed
export PURE_MM_TIMEOUT_V1628=${PURE_MM_TIMEOUT_V1628:-540}
exec sh "$here/../pure-mm-lifecycle-v1628/replay-v1628.sh"
