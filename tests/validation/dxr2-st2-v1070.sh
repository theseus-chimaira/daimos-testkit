#!/bin/sh
# Test the production DAS host DXR2 checker, without target boot.
set -eu
: "${DAS_REPO:?Set DAS_REPO to the DAS source directory}"
: "${TMPDIR:=$HOME/tmp}"
here=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
work="$TMPDIR/dxr2-st2-v1070-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
    "$DAS_REPO/dxrcheck.c" -o "$work/dxrcheck-v1070"
python3 "$here/tests/validation/dxr2-st2-v1070.py" \
    "$work/dxrcheck-v1070" "$work"
