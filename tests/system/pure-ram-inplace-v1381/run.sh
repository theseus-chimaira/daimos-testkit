#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
src="$DAIMOS_REPO/system/kernel"
cc -D_GNU_SOURCE -DDAIMOS_TEST_HOST_WORD_ADDR \
    -DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 \
    -std=c89 -O2 -Wall -Wextra -Werror -pedantic \
    -I"$src/proc" -I"$src/core" -I"$src/mm" -I"$src/fs" \
    -I"$src/storage" -I"$src/modules" -I"$src/drivers" \
    -I"${PDP10_PREFIX:-$HOME/cross}/include" \
    "$src/proc/proc_pure_ram_v1381.c" \
    "$src/proc/proc_storage_map_v28.c" \
    "$src/proc/proc_packed_layout_v36.c" \
    "$src/proc/proc_packed_owner_v37.c" \
    "$(dirname "$0")/test-host-v1381.c" \
    -o "$TMPDIR/pure-ram-inplace-v1381-host"
"$TMPDIR/pure-ram-inplace-v1381-host"
