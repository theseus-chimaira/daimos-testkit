#!/bin/sh
# Real 256K PDP-6 D6FS root on DRM236: detach its selected DR0..DR3.
# Reuse the accepted v1540 full-guest read/verification, not a fake I/O.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export DAIMOS_D6FS_ROOT_DRM_V1543=1
exec sh "$self/daimos-d6fs-root-outage-fullguest-v1540.sh"
