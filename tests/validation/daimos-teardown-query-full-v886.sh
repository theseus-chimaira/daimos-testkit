#!/bin/sh
# Full-system PDP-6: live UUO query and deferred MM owner diagnosis.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_UAREA_TEST_MODE=noncurrent
DAIMOS_UAREA_TEST_FAIR_V884=1
DAIMOS_UAREA_TEST_QUERY_V886=1
DAIMOS_UAREA_TEST_PROGRAM="$self/daimos-teardown-query-full-v886.c"
export DAIMOS_UAREA_TEST_MODE DAIMOS_UAREA_TEST_FAIR_V884
export DAIMOS_UAREA_TEST_QUERY_V886 DAIMOS_UAREA_TEST_PROGRAM
sh "$self/daimos-uarea-pin-integration-v882.sh"
echo 'v886: full-system normal/invalid UUO query, pending MM stage/delay and eventual cleanup PASS'
