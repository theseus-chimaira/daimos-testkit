#!/bin/sh
# E11: real RUN descriptor exhaustion in a separate live process parent,
# followed by genuine BRK OOM in another child; both OOM policies.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
V1114_TEST_MM_SLOTS=1 V1116_TEST_RUN_CAUSE=1 \
 V1158_TEST_COMBINED=1 V1075_TEST_OOM_ENABLED=${V1158_OOM_ENABLED:-1} \
 sh "$self/daimos-oom-requester-live-v1075.sh"
