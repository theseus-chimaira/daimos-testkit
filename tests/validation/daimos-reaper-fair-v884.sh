#!/bin/sh
# Full-system PDP-6: deferred MM cleanup alongside a continuous spinner.
set -eu
export DAIMOS_UAREA_TEST_MODE=noncurrent
export DAIMOS_UAREA_TEST_FAIR_V884=1
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export DAIMOS_UAREA_TEST_PROGRAM="$self/daimos-reaper-fair-v884.c"
sh "$self/daimos-uarea-pin-integration-v882.sh"
echo 'v884: full-system MM_BUSY reaped while an independent user remained continuously runnable PASS'
