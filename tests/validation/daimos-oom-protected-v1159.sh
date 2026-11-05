#!/bin/sh
# E12: actual physical BRK OOM under a real foreign FS lease,
# with protected INIT, original holder and independent witnesses.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
V1150_TEST_HELD_PROVIDER=1 V1159_TEST_PROTECTED=1 \
 V1075_TEST_OOM_ENABLED=${V1159_OOM_ENABLED:-1} \
 sh "$self/daimos-oom-requester-live-v1075.sh"
