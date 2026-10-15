#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${DISKDIR:?Set DISKDIR to completed PDP-6 diskset}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:=$HOME/tmp}"
base=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_REPO="$DAIMOS_REPO" DISKDIR="$DISKDIR" sh "$base/run-extract-v077.sh"
work="$TMPDIR/d6codec-export-run-v077"
python3 "$base/make-native-v077.py" "$work/source" "$work/group" "$work/native-v077.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 20 --workdir "$work/native-runtime" \
 --name d6codec-userspace-native-v077 --expect __test_exit=0 \
 "$base/../../validation/daimos-test-crt0-v1.s" \
 "$work/native-v077.s" \
 "$DAIMOS_REPO/system/kernel/core/d6codec_decode_group_v061.s"
