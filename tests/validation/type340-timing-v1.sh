#!/bin/sh
set -eu

: "${TMPDIR:?TMPDIR must be set}"
: "${SIMS_REPO:?SIMS_REPO must be set}"

tag=type340-timing-v1
work=$TMPDIR/$tag-$$
trap 'rm -rf "$work"' 0 1 2 3 15
mkdir -p "$work"

cc -std=c99 -O2 -Wall -Wextra -Werror -DTY340_NODISPLAY \
        -I"$SIMS_REPO/display" -I"$SIMS_REPO" \
        tests/validation/type340-timing-v1.c \
        "$SIMS_REPO/display/type340.c" -o "$work/$tag"
"$work/$tag"
