#!/bin/sh
# Full-profile PDP-6 LOGSTORE direct-device ABI acceptance: the 128K,
# 192K and 256K guests must not corrupt AUXSTORE block zero on either
# of two real cold boots, and must restore strict MEMFS XIP content.
set -eu
export TMPDIR="${TMPDIR:-$HOME/tmp}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

for size in ${XIP_V1484_SIZES:-128 192 256}; do
    case "$size" in
        128|192|256) ;;
        *) echo "v1484: unsupported full-profile RAM size: $size" >&2; exit 2 ;;
    esac
    echo "=== v1484 LOGSTORE/DRM ABI and MEMFS snapshot: ${size}K ==="
    XIP_V1477_SIZE="$size" \
    XIP_V1477_WORK="${XIP_V1484_WORK_PREFIX:-$TMPDIR/daimos-logstore-abi-v1484}-$size" \
    XIP_V1477_KEEP="${XIP_V1484_KEEP:-0}" \
        sh "$self/daimos-memfs-snapshot-reboot-v1477.sh"
done
echo 'PASS v1484: AUXSTORE descriptor, LOGSTORE DMA and MEMFS XIP reboot matrix'
