#!/bin/sh
# Capture the exact PURE-OFF five-sleeping-child state before the
# original source's sixth RUN. Source and KCORE match v1629 ON.
set -eu
: "${PURE_OFF_BUILD_V1631:?preserved v1631 PURE-disabled build required}"
export PURE_OFF_STOP_V1632=five
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
exec sh "$here/../pure-capacity-baseline-v1631/replay-v1631.sh"
