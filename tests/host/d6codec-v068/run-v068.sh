#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR/d6codec-host-test-v068"
cc -std=c99 -O2 -Wall -Wextra -Werror \
  -I"$DAIMOS_REPO/tools/host" \
  -o "$TMPDIR/d6codec-host-test-v068/regress-v068" \
  "$(dirname "$0")/regress-v068.c" \
  "$DAIMOS_REPO/tools/host/d6codec-codec-v068.c"
"$TMPDIR/d6codec-host-test-v068/regress-v068"
cc -std=c99 -O2 -Wall -Wextra -Werror \
  -o "$TMPDIR/d6codec-host-test-v068/d6codec-v068" \
  "$DAIMOS_REPO/tools/host/d6codec-v068.c" \
  "$DAIMOS_REPO/tools/host/d6codec-codec-v068.c"
python3 "$(dirname "$0")/check-corpus-v068.py" \
 "$(cd "$(dirname "$0")/../../.." && pwd)" \
 "$TMPDIR/d6codec-host-test-v068/d6codec-v068" \
 "$TMPDIR/d6codec-host-test-v068/corpus"
