#!/bin/sh
# Real P6 production V2/RW marked DIRTY, physical READ_SUSPECT,
# wrong reel refusal, original DIRTY readback, then CLEAN on unmount.
# The detach/replace sequence is a TEST fault, not permitted operation.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}" "${DAIMOS_TSFS_PREBUILT_BUILD:?}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_TSFS_GATE_DTVOL2_V1564=1
export DAIMOS_TSFS_GATE_MEDIA_V1527=1
export DAIMOS_TSFS_GATE_OP_RETURN_V1572=1
export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-media-return-v1527.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSMEDIA V1527'
export DAIMOS_TSFS_GATE_STAGES_V1526='START RW_ARMED READY_DETACH OFFLINE_REFUSED READY_SWAP REPLACEMENT_REFUSED READY_RESTORE RETURN_VERIFIED PASS'
exec sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
