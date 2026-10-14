#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
out="$TMPDIR/mm-native-relocation-v099"
mkdir -p "$out"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
  --exec-mode go --start 1000 --timeout 30 --workdir "$out/run" \
  --name mm-native-relocation-v099 --expect __test_exit=0 \
  "$(dirname "$0")/../../../validation/d6codec-native-v051/crt_stack_v051.s" \
  "$(dirname "$0")/test-v099.s" \
  "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" \
  "$(dirname "$0")/../table-v133.s" \
  "$(dirname "$0")/deps-v099.s"
