#!/bin/sh
# Exercise three TSFS system members through the v20 lowmem boot harness.
set -eu
TSFS_ROOT_MEMBERS=3
export TSFS_ROOT_MEMBERS
exec sh "$(dirname "$0")/../tsfs-gcc-lowmem-v20/run.sh"
