#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${TESTKIT_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR/d6codec-host-v060"
cc -std=c99 -O2 -Wall -Wextra -Werror \
  -I"$DAIMOS_REPO/tools/host" \
  -o "$TMPDIR/d6codec-host-v060/d6codec-v060" \
  "$DAIMOS_REPO/tools/host/d6codec-v060.c" \
  "$DAIMOS_REPO/tools/host/d6codec-codec-v060.c"
cc -std=c99 -O2 -Wall -Wextra -Werror \
  -I"$DAIMOS_REPO/tools/host" \
  -o "$TMPDIR/d6codec-host-v060/decode-regress-v060" \
  "$TESTKIT_REPO/tests/host/d6codec-v060/decode-regress-v060.c" \
  "$DAIMOS_REPO/tools/host/d6codec-codec-v060.c"
"$TMPDIR/d6codec-host-v060/decode-regress-v060"
python3 "$TESTKIT_REPO/tests/host/d6codec-v059/check-golden-v059.py" \
  "$TESTKIT_REPO/tests/validation/d6codec-native-v051/test_darc_v051.s" \
  "$TMPDIR/d6codec-host-v060/d6codec-v060" \
  "$TMPDIR/d6codec-host-v060"
python3 "$TESTKIT_REPO/tests/host/d6codec-v059/check-corpus-v059.py" \
  "$TESTKIT_REPO" \
  "$TMPDIR/d6codec-host-v060/d6codec-v060" \
  "$TMPDIR/d6codec-host-v060/corpus"
