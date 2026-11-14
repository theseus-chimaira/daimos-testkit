#!/bin/sh
# v1555: userspace DTFS probe recognizes only healthy DTVOL2/CLEAN.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-dtfs-v2-probe-v1555.XXXXXX")
if [ "${V1555_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

${HOST_CC:-cc} -std=c89 -O2 -Wall -Wextra -Werror \
    -I "$DAIMOS_REPO/userland/libc" \
    -I "$DAIMOS_REPO/userland/dtfs" \
    -I "$DAIMOS_REPO/system/kernel/proc" \
    -I "$DAIMOS_REPO/system/kernel/fs" \
    -I "$DAIMOS_REPO/system/kernel/core" \
    -I "$DAIMOS_REPO/system/kernel/storage" \
    -I "$DAIMOS_REPO/tools/host" \
    -o "$work/probe-v1555" \
    "$self/daimos-dtfs-v2-probe-v1555.c" \
    "$DAIMOS_REPO/userland/dtfs/dtfs_probe.c"
"$work/probe-v1555"
echo 'PASS v1555: source-linked C89 DTFS DTVOL2 probe'
