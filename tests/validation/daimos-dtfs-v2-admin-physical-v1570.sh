#!/bin/sh
# Full Type-551 DTVOL2 administrative recovery after real partial DATA.
# Uses the v1568 source-matched disposable RW test image, then boots
# the original DIRTY reel and independent CLEAN replacement with the
# entirely unmodified production KCORE/MRES. Never enables V2 RW there.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export V1568_MODE=admin
exec sh "$self/daimos-dtfs-v2-partial-data-v1568.sh"
