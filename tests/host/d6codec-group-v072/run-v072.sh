#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${TMPDIR:=$HOME/tmp}"
mkdir -p "$TMPDIR"
for case in test-v072 test-mini-v072; do
 cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic \
  -I"$DAIMOS_REPO/tools/host" \
  "$DAIMOS_REPO/tools/host/d6codec-group-v071.c" \
  "$DAIMOS_REPO/tools/host/d6codec-group-v072.c" \
  "$(dirname "$0")/$case.c" -o "$TMPDIR/$case"
 "$TMPDIR/$case"
done
