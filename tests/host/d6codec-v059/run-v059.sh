#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${TESTKIT_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR/d6codec-host-v059"
cc -std=c99 -O2 -Wall -Wextra -Werror \
  -o "$TMPDIR/d6codec-host-v059/d6codec-v059" \
  "$DAIMOS_REPO/tools/host/d6codec-v059.c"
python3 "$TESTKIT_REPO/tests/host/d6codec-v059/check-golden-v059.py" \
  "$TESTKIT_REPO/tests/validation/d6codec-native-v051/test_darc_v051.s" \
  "$TMPDIR/d6codec-host-v059/d6codec-v059" \
  "$TMPDIR/d6codec-host-v059"
python3 "$TESTKIT_REPO/tests/host/d6codec-v059/check-corpus-v059.py" \
  "$TESTKIT_REPO" \
  "$TMPDIR/d6codec-host-v059/d6codec-v059" \
  "$TMPDIR/d6codec-host-v059/corpus"
