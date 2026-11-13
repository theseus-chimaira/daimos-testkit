#!/bin/sh
# Real PDP-6 TSFS-root + validated and mounted D6FS secondary DSK/DRM.
# Only the secondary media are detached. No fake kernel I/O result.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kind=${1:-dsk}
case "$kind" in dsk|drm) ;; *) echo 'usage: script [dsk|drm]' >&2; exit 2;; esac
if [ -n "${V1545_REUSE_WORK:-}" ]; then
    work=$V1545_REUSE_WORK
    test -d "$work" || { echo 'v1545: nonexistent reuse work' >&2; exit 1; }
else
    work=$(mktemp -d "$TMPDIR/daimos-secondary-d6fs-v1545-$kind.XXXXXX")
fi
if [ "${V1545_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi
source_build=${DAIMOS_TSFS_PREBUILT_BUILD:-$DAIMOS_REPO/build/system/boot/pdp6}
test -f "$source_build/kinit.block.words" && \
test -f "$source_build/boot.ini" || {
    echo 'v1545: full KCC PDP-6 build required for libc and KINIT words' >&2
    exit 1
}
libc="$source_build/userland-build/userland/command/libc"
for obj in crt0 syscall syscall_helpers u text; do
    test -s "$libc/$obj.dobj" || {
        echo "v1545: no matching production libc $obj" >&2
        exit 1
    }
done
init="$source_build/userland-build/userland/init.dxr"
test -f "$init" || { echo 'v1545: missing production INIT DXR' >&2; exit 1; }

# Build independent, real D6FS diskset: 4 equal-sized Type-270 or
# Type-236 native media. A physically detached block must be requested
# through the full D6FS FILE VFS stack after mounting, not a raw probe.
media="$work/media"
"$PDP10_PREFIX/bin/mkdsk" -n 4 -m clean \
    -p "$source_build/kinit.block.words" -o "$media" --d6fs-layout \
    --logstore-blocks 0 --badmap-blocks 0 \
    --swap-tail-blocks 0 --spare-blocks 0 \
    --member-sectors 020000,020000,020000,020000
"$PDP10_PREFIX/bin/mkd6fs" -n 4 -d "$media" -D /SYSTEM:0555 \
    -f "/SYSTEM/INIT:$init:0555:dxr"
"$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$media" \
    > "$work/media-validation-v1545.log" 2>&1
grep -q 'FCBs: clean' "$work/media-validation-v1545.log" || {
    cat "$work/media-validation-v1545.log" >&2
    exit 1
}
python3 "$self/daimos-secondary-d6fs-media-handoff-v1545.py" \
    "$media" "$kind" "$work/secondary-handoff-v1545.h"
python3 "$self/daimos-secondary-d6fs-handoff-negative-v1545.py" \
    "$self" "$media"

# Compile the actual PID1 syscall client using the accepted production
# libc and KCC. The handoff is generated from the same verified media
# that SIMH attaches, never guessed or fabricated inside KCORE.
incs="-I$work"
for d in boot core drivers fs mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$d"
done
incs="$incs -I$DAIMOS_REPO/userland/libc -I$PDP10_PREFIX/include"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $incs \
    -S "$self/../target/daimos-secondary-d6fs-physical-v1545.c" \
    -o "$work/guest-v1545.s"
"$PDP10_PREFIX/bin/das" -F -C -O "$work/guest-v1545.dobj" \
    "$work/guest-v1545.s"
"$PDP10_PREFIX/bin/dlink" --daimos-uuo-relax -b 020 \
    -o "$work/guest-v1545.dxr" -M "$work/guest-v1545.map" \
    "$libc/crt0.dobj" "$libc/syscall.dobj" \
    "$libc/syscall_helpers.dobj" "$work/guest-v1545.dobj" \
    "$libc/u.dobj" "$libc/text.dobj"
"$PDP10_PREFIX/bin/dxrcheck" "$work/guest-v1545.dxr"

if [ "$kind" = dsk ]; then
    # The selected root must not be physically backed by the same DSK
    # controller we are about to detach. The DRM236-root D6FS MRES is
    # already installed by KINIT and can mount a secondary D6FS.
    selected_root_v1545=drum
    selected_boot_v1545=drm
else
    selected_root_v1545=disk
    selected_boot_v1545=dsk
fi
echo "v1545: building isolated ROOT=$selected_root_v1545 image"
if ! PATH="$PDP10_PREFIX/bin:$PATH" \
    make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$work/build" \
    USERLAND_BUILD_ROOT="$source_build/userland-build" \
    SYSTEM_INIT_DXR="$work/guest-v1545.dxr" \
    ROOT="$selected_root_v1545" BOOT="$selected_boot_v1545" \
    COMPILER=kcc PROC_BOOT_USERS=1 PDP10_PREFIX="$PDP10_PREFIX" \
    HOST_TOOLS="$PDP10_PREFIX/bin" \
    > "$work/root-image-build-v1545.log" 2>&1; then
    tail -75 "$work/root-image-build-v1545.log" >&2
    exit 1
fi
test -f "$work/build/kcore.map"

export DAIMOS_TSFS_PREBUILT_BUILD="$work/build"
export DAIMOS_DTFS_DISK_ROOT_V1524=1
export DAIMOS_TSFS_GATE_BINARY_V1525="$work/guest-v1545.dxr"
export DAIMOS_TSFS_GATE_DXR_V1525="$work/guest-v1545.dxr"
export DAIMOS_TSFS_GATE_RUN_V1525=1
export DAIMOS_TSFS_GATE_INIT_V1525=1
export DAIMOS_TSFS_MOUNT_PREFORMATTED_V1525=1
export DAIMOS_TSFS_GATE_PREFIX_V1526='SECD6FS V1545'
export DAIMOS_TSFS_GATE_STAGES_V1526='START MOUNTED READY_DETACH SECONDARY_FAILED ROOT_ALIVE PASS'
export DAIMOS_D6FS_SECONDARY_FAULT_V1545=1
export DAIMOS_D6FS_SECONDARY_CLASS_V1545="$kind"
export DAIMOS_D6FS_SECONDARY_MEDIA_DIR_V1545="$media"
echo "v1545: booting D6FS $selected_root_v1545 root with mounted secondary $kind"
sh "$self/daimos-dtfs-tape-root-mount-v578.sh"
echo "PASS v1545: full physical secondary $kind D6FS failure nonfatal"
