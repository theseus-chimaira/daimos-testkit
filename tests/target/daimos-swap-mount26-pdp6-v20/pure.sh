#!/bin/sh
# Reuse the native raw/compressed/verify PURE I/O fixture at public mount 26.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
EXTRA_TEST_FLAGS='-DTEST_MOUNT_ID=26U'
export EXTRA_TEST_FLAGS
sh "$self/../daimos-swap-pure-text-pdp6-v1/run.sh"
echo 'swap-mount26-pure-v20: PASS (mount26 full swap-out/reload; raw, compressed and verifier)'
