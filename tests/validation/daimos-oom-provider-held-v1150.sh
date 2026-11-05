#!/bin/sh
# B06: true physical BRK OOM with a live provider owner and waiter.
# The owner is resumed by a test-only event; the lease is unlocked only
# by its original kernel continuation, never by another process.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
V1150_TEST_HELD_PROVIDER=1 V1075_TEST_OOM_ENABLED=${V1150_OOM_ENABLED:-1} \
    sh "$self/daimos-oom-requester-live-v1075.sh"
