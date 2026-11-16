#!/bin/sh
# v1612 folded PURE KINIT package selection, invoked from testkit.
set -eu
: "${DAIMOS_REPO:?}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
exec sh "$here/../pure-service-v1611/boot-mode-v1611.sh"
