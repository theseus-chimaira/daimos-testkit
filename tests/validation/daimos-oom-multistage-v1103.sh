#!/bin/sh
# One disposable PDP-6 guest: PIPE/MM, HUP boundary, VM and u-area.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DAIMOS_V1103_MULTISTAGE=1 sh "$self/daimos-oom-pre-vm-retry-v997.sh"
