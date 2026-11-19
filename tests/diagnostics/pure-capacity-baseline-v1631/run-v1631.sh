#!/bin/sh
# Matched 48K PURE-OFF physical guest: same 5-child source, kernel
# profile and executable as v1629, differing in installed PURE MRES.
# Observational only: retain full console and linked builds.
set -eu
: "${DAIMOS_REPO:?matching DAIMOS checkout required}"
export PURE_ENABLE_V1631=0
export PURE_PRESSURE_TIMEOUT_V1614=${PURE_PRESSURE_TIMEOUT_V1614:-480}
export KEEP_TEST=1
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
exec sh "$here/../pure-packed-lifecycle-v1629/run-v1629.sh"
