#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${TMPDIR:=$HOME/tmp}"
mkdir -p "$TMPDIR"
cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic \
 -I"$DAIMOS_REPO/tools/host" \
 "$DAIMOS_REPO/tools/host/d6codec-group-v071.c" \
 "$(dirname "$0")/test-v071.c" -o "$TMPDIR/d6codec-group-v071-test"
"$TMPDIR/d6codec-group-v071-test"
