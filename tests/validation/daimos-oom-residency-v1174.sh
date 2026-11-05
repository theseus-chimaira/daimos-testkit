#!/bin/sh
# Full-guest permanent KCORE/MM-table/MRES audit for DSK/D6FS release media.
# Use the unmodified MRES installer and live SYS_MEMINFO syscall.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
V1174_TEST_RESIDENCY=1 \
    sh "$self/daimos-oom-release-media-v1160.sh"
