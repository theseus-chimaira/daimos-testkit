#!/bin/sh
# Offline validation against an already completed userspace -G system run.
# DISKDIR points to the simulator's real one-member D6FS diskset.
set -eu
: "${DAIMOS_REPO:?}"
: "${DISKDIR:?Set DISKDIR to a completed PDP-6 D6FS diskset}"
: "${TMPDIR:=$HOME/tmp}"
mkdir -p "$TMPDIR/d6codec-export-run-v077"
work="$TMPDIR/d6codec-export-run-v077"
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -Wno-unused-function \
 -I"$DAIMOS_REPO/tools/host" \
 "$(dirname "$0")/export-v077.c" -o "$work/export"
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -pedantic \
 -I"$DAIMOS_REPO/tools/host" \
 "$(dirname "$0")/verify-v077.c" \
 "$DAIMOS_REPO/tools/host/d6codec-group-v071.c" -o "$work/verify"
"$work/export" "$DISKDIR" /CONFIG/PASSWD "$work/source"
"$work/export" "$DISKDIR" /TEMP/GRP "$work/group"
"$work/verify" "$work/source" "$work/group"
