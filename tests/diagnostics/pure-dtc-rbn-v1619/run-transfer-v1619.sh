#!/bin/sh
# Real 48K PURE guest: capture matched RBN 4, PI3 DTC read arming,
# and DCT successful read completion against original TAPE DXR bytes.
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PURE_RBN_TRANSFER_V1619=1
export PURE_RBN_TRANSFER_V1619
exec sh "$here/run-physical-trap-v1619.sh"
