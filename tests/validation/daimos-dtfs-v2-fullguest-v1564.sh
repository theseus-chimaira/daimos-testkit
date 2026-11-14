#!/bin/sh
# Physical DTVOL2/CLEAN, two real PDP-6 processes and tested RO admission.
# Uses the existing v1525/v1526 TSFS-root physical fixture exclusively.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-v2-fullguest-v1564.XXXXXX")
if [ "${DAIMOS_TSFS_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

if [ -z "${DAIMOS_TSFS_PREBUILT_BUILD:-}" ]; then
    export DAIMOS_TSFS_PREBUILT_BUILD="$work/guest-build"
    echo 'v1564: building isolated full 256K physical TSFS-root KCC image'
    PATH="$PDP10_PREFIX/bin:$PATH" make \
        -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$DAIMOS_TSFS_PREBUILT_BUILD" \
        USERLAND_BUILD_ROOT="$DAIMOS_TSFS_PREBUILT_BUILD" \
        ROOT=tape BOOT=ptr PDP10_PREFIX="$PDP10_PREFIX" \
        PROC_BOOT_USERS=1 HOST_TOOLS="$PDP10_PREFIX/bin" \
        > "$work/image-build-v1564.log" 2>&1 || {
        tail -90 "$work/image-build-v1564.log" >&2
        exit 1
    }
fi

export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-cross-owner-v1526.c"
export DAIMOS_TSFS_GATE_DTVOL2_V1564=1
export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSV2 V1564'
export DAIMOS_TSFS_GATE_STAGES_V1526='START RW_REFUSED MOUNTED CROSS_CWD_REFUSED CROSS_FILE_REFUSED CROSS_RETIRED REMOUNTED PASS'

echo 'v1564: full physical DTVOL2/CLEAN guest cross-owner acceptance'
sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"

# Reboot independently against a newly formatted disposable DTVOL2 whose
# RBN0 has a valid WRITE_INTENT seal. The real DTFS parser must reject it
# even with SYS_MOUNT_RDONLY, without publishing a VFS slot or changing
# any physical tape byte. Reuse the exact same already-built KCORE image.
export DAIMOS_TSFS_GATE_V2_DIRTY_V1564=1
export DAIMOS_TSFS_GATE_SOURCE_V1526="$self/../target/daimos-dtfs-v2-dirty-gate-v1564.c"
export DAIMOS_TSFS_GATE_PREFIX_V1526='DTFSV2DIRTY V1564'
export DAIMOS_TSFS_GATE_STAGES_V1526='START RW_REFUSED RO_REFUSED UNPUBLISHED PASS'
echo 'v1564: second physical PDP-6 cold boot from valid DIRTY DTVOL2'
sh "$self/daimos-dtfs-kcore-physical-fullguest-v1525.sh"
echo 'PASS v1564: two real physical guest boots, CLEAN and WRITE_INTENT'
