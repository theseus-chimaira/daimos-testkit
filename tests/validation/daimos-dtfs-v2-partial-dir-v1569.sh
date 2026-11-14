#!/bin/sh
# v1569: two booted PDP-6 guests, real Type-551 partial V2 directory.
# v1568 remains the source-matched disposable RW test image builder;
# choose its exact DIR test path and the original production cold boot.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export V1568_MODE=dir
exec sh "$self/daimos-dtfs-v2-partial-data-v1568.sh"
