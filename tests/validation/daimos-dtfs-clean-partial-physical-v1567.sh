#!/bin/sh
# REAL Type-551 changed-word physical RBN0 CLEAN failure and cold boot.
# A disposable v1566 test image physically arms DIRTY (v1551/v1552),
# then the normal production CLEAN write is interrupted by the existing
# v1529 diagnostic simulator's one-changed-word failure mechanism.
# The resulting torn tape is cold booted by the unmodified production
# KCORE, which must reject both RW and RO mounts without touching bytes.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_TSFS_SIMH="${DAIMOS_TSFS_SIMH:-$PDP10_PREFIX/bin/pdp6-v1529r5}"
test -x "$DAIMOS_TSFS_SIMH" || {
    echo 'v1567: diagnostic Type-551 PARTIALWRITE simulator missing' >&2
    exit 1
}
strings "$DAIMOS_TSFS_SIMH" | grep -q PARTIALWRITE || {
    echo 'v1567: simulator lacks REAL changed-word PARTIALWRITE' >&2
    exit 1
}
export V1567_PHYSICAL_CLEAN_PARTIAL=1
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
sh "$self/daimos-dtfs-clean-physical-v1566.sh"
