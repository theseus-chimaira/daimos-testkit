#!/bin/sh
# Extend v197 with real vm_space_create exhaustion, retaining its normal run.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
DAIMOS_RUN_VM_CREATE_OOM_V199=1
export DAIMOS_RUN_VM_CREATE_OOM_V199
exec sh "$self/daimos-run-late-rollback-v197.sh"
