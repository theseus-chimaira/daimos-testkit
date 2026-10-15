#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:=/usr/local}"
: "${TMPDIR:=$HOME/tmp}"
mkdir -p "$TMPDIR/d6codec-host-native-v074"
base=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic \
 -I"$DAIMOS_REPO/tools/host" "$base/gen-v074.c" \
 "$DAIMOS_REPO/tools/host/d6codec-group-v072.c" \
 -o "$TMPDIR/d6codec-host-native-v074/generator"
"$TMPDIR/d6codec-host-native-v074/generator" > "$TMPDIR/d6codec-host-native-v074/generated.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 20 --workdir "$TMPDIR/d6codec-host-native-v074/runtime" \
 --name d6codec-host-native-v074 --expect __test_exit=0 \
 "$base/../../validation/daimos-test-crt0-v1.s" "$base/test-v074.s" \
 "$TMPDIR/d6codec-host-native-v074/generated.s" \
 "$DAIMOS_REPO/system/kernel/core/d6codec_decode_group_v061.s"
