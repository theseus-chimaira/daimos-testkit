#!/bin/sh
# Full booted PDP-6 TSFS root + native secondary DTFS cwd-busy lifecycle.
# Reuse the accepted v578 full guest runner with a narrowly scoped v1523
# assertion; do not build a second shadow boot harness.
set -eu
export DAIMOS_TSFS_CHECK_MOUNT_CWD_BUSY=1
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
exec sh "$self/daimos-dtfs-tape-root-mount-v578.sh"
