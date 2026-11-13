#!/bin/sh
# v1540: full 256K PDP-6 D6FS-root physical disk outage. No simulator
# media-state flags or fake I/O returns: remove actual DSK attachments.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-d6fs-root-outage-v1540.XXXXXX")
if [ "${V1540_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

# Compile the same exercised v1538 root data-read witness as actual PID1.
# The disk image builder accepts SYSTEM_INIT_DXR as a root file dependency.
# Use the real production libc/UUO ABI, never a test syscall emulator.
incs=
for d in boot core drivers fs mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$d"
done
incs="$incs -I$DAIMOS_REPO/userland/libc -I$PDP10_PREFIX/include"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $incs \
    -S "$self/../target/daimos-root-outage-physical-v1538.c" \
    -o "$work/guest-v1540.s"
"$PDP10_PREFIX/bin/das" -F -C -O "$work/guest-v1540.dobj" \
    "$work/guest-v1540.s"
userland="$DAIMOS_REPO/build/system/boot/pdp6/userland-build"
base="$userland/userland/command/libc"
for obj in crt0 syscall syscall_helpers u text; do
    test -f "$base/$obj.dobj" || {
        echo "v1540: missing real production libc $obj" >&2
        exit 1
    }
done
"$PDP10_PREFIX/bin/dlink" --daimos-uuo-relax -b 020 \
    -o "$work/guest-v1540.dxr" -M "$work/guest-v1540.map" \
    "$base/crt0.dobj" "$base/syscall.dobj" \
    "$base/syscall_helpers.dobj" "$work/guest-v1540.dobj" \
    "$base/u.dobj" "$base/text.dobj"
"$PDP10_PREFIX/bin/dxrcheck" "$work/guest-v1540.dxr"

# Use a private complete matching-source KCC image. Root D6FS media are
# generated from the actual mkd6fs production layout and hold this PID1
# as /SYSTEM/INIT; no private boot ROM, KCORE hook or filesystem shim.
printf '%s\n' 'v1540: building isolated full D6FS root image'
if ! PATH="$PDP10_PREFIX/bin:$PATH" \
    make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$work/build" USERLAND_BUILD_ROOT="$userland" \
    SYSTEM_INIT_DXR="$work/guest-v1540.dxr" \
    ROOT=disk BOOT=dsk COMPILER=kcc PROC_BOOT_USERS=1 \
    PDP10_PREFIX="$PDP10_PREFIX" HOST_TOOLS="$PDP10_PREFIX/bin" \
    > "$work/disk-image-build-v1540.log" 2>&1; then
    tail -75 "$work/disk-image-build-v1540.log" >&2
    echo 'v1540: full D6FS-root build failed' >&2
    exit 1
fi
test -s "$work/build/kcore.map"
test -s "$work/build/disk/dsk0.dsk"
printf '%s\n' 'v1540: booting real PDP-6 and detaching all D6FS root disks'

export DAIMOS_TSFS_PREBUILT_BUILD="$work/build"
export DAIMOS_DTFS_DISK_ROOT_V1524=1
export DAIMOS_TSFS_GATE_RUN_V1525=1
export DAIMOS_TSFS_GATE_INIT_V1525=1
export DAIMOS_TSFS_MOUNT_PREFORMATTED_V1525=1
export DAIMOS_TSFS_GATE_PREFIX_V1526='ROOTLOSS V1538'
export DAIMOS_TSFS_GATE_STAGES_V1526='START READY_DETACH'
export DAIMOS_D6FS_GATE_ROOTLOSS_V1540=1
sh "$self/daimos-dtfs-tape-root-mount-v578.sh"
