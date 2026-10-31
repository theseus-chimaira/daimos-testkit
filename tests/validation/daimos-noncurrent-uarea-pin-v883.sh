#!/bin/sh
# Full-system PDP-6: inject genuine MM_BUSY in non-current HUP teardown.
set -eu
DAIMOS_UAREA_TEST_MODE=noncurrent
export DAIMOS_UAREA_TEST_MODE
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
sh "$self/daimos-uarea-pin-integration-v882.sh"
echo 'v883: full-system noncurrent fatal HUP committed and deferred u-area released PASS'
