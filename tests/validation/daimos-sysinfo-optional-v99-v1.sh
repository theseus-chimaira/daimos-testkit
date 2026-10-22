#!/bin/sh
# Build a 256K runtime with no SYSINFO MRES and check syscall -1 fallback.
set -eu
SYSINFO_MRES_ENABLED=0
export SYSINFO_MRES_ENABLED
exec "$(dirname "$0")/daimos-kcore-oneptr-v97-v1.sh"
