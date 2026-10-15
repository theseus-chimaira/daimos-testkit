#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${TMPDIR:=$HOME/tmp}"
mkdir -p "$TMPDIR/d6codec-single-v082"
cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic \
 -I"$DAIMOS_REPO/tools/host" \
 "$(dirname "$0")/check-v082.c" \
 "$DAIMOS_REPO/tools/host/d6lz-codec.c" \
 "$DAIMOS_REPO/tools/host/d6codec-group-v071.c" \
 "$DAIMOS_REPO/tools/host/d6codec-group-v072.c" \
 -o "$TMPDIR/d6codec-single-v082/check"
"$TMPDIR/d6codec-single-v082/check"
