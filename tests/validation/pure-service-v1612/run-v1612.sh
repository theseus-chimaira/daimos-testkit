#!/bin/sh
# The v1612 MM-owner scan is source-linked with all original v1611
# transactions plus the extra duplicate-owner and pin-failure cases.
set -eu
: "${DAIMOS_REPO:?}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_TEST_PURE_SERVICE_V1612=1
export DAIMOS_TEST_PURE_SERVICE_V1612
exec sh "$here/../pure-service-v1611/run-v1611.sh"
