#!/bin/sh
# A TSFS-root kernel must not install D6FS merely because DSK/DRM hardware
# exists.  Those devices remain available for raw swap, LOGSTORE, and MEMFS.
# This test links the real target kernel but deliberately does not construct
# the full TSFS media image (whose single-tape capacity gate is separate).
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO is required}"
: "${PDP10_PREFIX:?PDP10_PREFIX is required}"
: "${TMPDIR:?TMPDIR is required}"

tag=daimos-tsfs-root-no-d6fs-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
boot="$build/system/boot/pdp6"
cleanup() { rm -rf "$work"; }
trap cleanup EXIT HUP INT TERM

mkdir -p "$work"
PATH="$PDP10_PREFIX/bin:$PATH" \
    make -C "$DAIMOS_REPO/system/boot/pdp6" \
    ROOT=tape BOOT=dtc PDP10_PREFIX="$PDP10_PREFIX" BUILD_ROOT="$build" \
    permanent-size "$boot/kinit.dxr" > "$work/build.log" 2>&1 || {
        tail -45 "$work/build.log" >&2
        exit 1
    }

test -s "$boot/kinit.dxr" && test -s "$boot/kinit.map" || {
        echo "$tag: TSFS kernel did not link" >&2; exit 1;
    }
grep -qx '\.set D6FS_FS_ENABLED,0' "$boot/module-table-runtime.s" || {
        echo "$tag: TSFS root did not disable D6FS" >&2; exit 1;
    }
if test -e "$boot/d6fs-mres.dobj" || \
    grep -Eq '(^|[[:space:]])(d6fs_minit|d6fs_mres_package)([[:space:]]|$)' \
    "$boot/kinit.map"; then
    echo "$tag: D6FS remains in the TSFS MINIT/MRES image" >&2
    exit 1
fi

# Presence of the raw auxiliary drivers and services is mandatory.  Absence
# of D6FS must never suppress swap, LOGSTORE, or MEMFS backing.
for name in dsk drm blockset badmap logstore memfs tape dtfs; do
    test -s "$boot/$name-mres.dobj" || {
        echo "$tag: missing auxiliary MRES package $name" >&2
        exit 1
    }
done
for sym in dsk_mres_package drm236_mres_package \
    logstore_mres_package memfs_mres_package; do
    grep -q "^$sym[[:space:]]" "$boot/kinit.map" || {
        echo "$tag: missing linked MRES package $sym" >&2
        exit 1
    }
done
grep -q '^SINGLE_ROOT[[:space:]]*limit=040000' "$work/build.log" || {
    echo "$tag: permanent-size acceptance was not checked" >&2
    exit 1
}
grep -q '^MULTI_ROOT[[:space:]]*limit=040000' "$work/build.log" || {
    echo "$tag: multi-member permanent-size acceptance was not checked" >&2
    exit 1
}

grep -E '^KCORE\+MRES|^MULTI_ROOT[[:space:]]|^MULTI_LAST[[:space:]]|^PERMANENT_LAST' \
    "$work/build.log"
echo "$tag: PASS (TSFS root without D6FS; DSK/DRM, swap, LOGSTORE and MEMFS available)"
