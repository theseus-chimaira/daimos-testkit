#!/bin/sh
# v1144: one-boot PIPE/DPY/VM/u-area physical fault with held provider.
# Test-only injections operate only in the disposable full PDP-6 image.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1103_MULTISTAGE=1 DAIMOS_V1106_PHYSICAL_VM=1 \
    DAIMOS_V1117_WAIT_CHURN=1 DAIMOS_V1144_DPY_MIXED=1 \
    sh "$self/daimos-oom-pre-vm-retry-v997.sh"
