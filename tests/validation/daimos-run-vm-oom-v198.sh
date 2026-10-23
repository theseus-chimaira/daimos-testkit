#!/bin/sh
# Reuse v197's known-good RUN fixture and add v198 physical-OOM assertions.
set -eu
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
DAIMOS_RUN_VM_OOM_V198=1
export DAIMOS_RUN_VM_OOM_V198
exec sh "$self/daimos-run-late-rollback-v197.sh"
