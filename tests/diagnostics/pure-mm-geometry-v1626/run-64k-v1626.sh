#!/bin/sh
# Run the original six-child PURE experiment on 64K, without auxiliary
# backing, for an independent physical VM-capacity/lifecycle control.
# A failure from the strict old BRK/R assertion remains non-accepting.
set -eu
: "${DAIMOS_REPO:?DAIMOS checkout required}"
export PURE_PHYS_KWORDS_V1626=64
export PURE_CHILDREN_V1624=6
export PURE_BRK_TARGET_V1624=017000
export PURE_PRESSURE_TIMEOUT_V1614=${PURE_PRESSURE_TIMEOUT_V1614:-490}
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
exec sh "$here/../pure-pressure-cause-v1624/run-v1624.sh"
