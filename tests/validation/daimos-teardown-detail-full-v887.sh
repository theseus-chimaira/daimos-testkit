#!/bin/sh
# Full guest: user-mode detail argument and truly pinned MM owner.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_UAREA_TEST_MODE=noncurrent
DAIMOS_UAREA_TEST_FAIR_V884=1
DAIMOS_UAREA_TEST_QUERY_V886=1
DAIMOS_UAREA_TEST_DETAIL_V887=1
DAIMOS_UAREA_TEST_PROGRAM="$self/daimos-teardown-detail-full-v887.c"
export DAIMOS_UAREA_TEST_MODE DAIMOS_UAREA_TEST_FAIR_V884
export DAIMOS_UAREA_TEST_QUERY_V886 DAIMOS_UAREA_TEST_DETAIL_V887
export DAIMOS_UAREA_TEST_PROGRAM
sh "$self/daimos-uarea-pin-integration-v882.sh"
echo 'v887: full-system detail UUO and actual pinned u-area ownership PASS'
