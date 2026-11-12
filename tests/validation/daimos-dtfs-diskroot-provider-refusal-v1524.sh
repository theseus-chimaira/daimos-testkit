#!/bin/sh
# Confirm the existing disk-root MRES policy rather than falsely treating
# an ordinary D6FS mountpoint STAT as a successfully mounted DTFS.
set -eu
export DAIMOS_DTFS_DISK_ROOT_V1524=1
export DAIMOS_EXPECT_DTFS_PROVIDER_REFUSAL_V1524=1
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
exec sh "$self/daimos-dtfs-tape-root-mount-v578.sh"
