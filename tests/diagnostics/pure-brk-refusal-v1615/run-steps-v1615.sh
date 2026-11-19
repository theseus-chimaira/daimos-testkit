#!/bin/sh
# Non-accepting physical 48K PDP-6 MM geometry experiment.
# Establish 014000 and 016000 APR extents, then request 020000.
# On success OR failure, the test-only HALT retains sleeping owners.
set -eu
: "${DAIMOS_REPO:?}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PURE_BRK_TARGET_V1615=020000
PURE_BRK_STEPS_V1615=1
PURE_PRESSURE_TIMEOUT_V1614=${PURE_PRESSURE_TIMEOUT_V1614:-230}
export PURE_BRK_TARGET_V1615 PURE_BRK_STEPS_V1615
export PURE_PRESSURE_TIMEOUT_V1614
exec sh "$here/run-v1615.sh"
