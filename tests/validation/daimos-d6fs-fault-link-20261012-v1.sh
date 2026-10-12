#!/bin/sh
# Build an isolated PDP-6 image with test-only D6FS backing error injection.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
: "${FAULT_LOGICAL:?set FAULT_LOGICAL (integer, base 0)}"
: "${TMPDIR:=$HOME/tmp}"
case "$FAULT_LOGICAL" in ''|*[!0-9xXa-fA-F]*) echo 'invalid FAULT_LOGICAL' >&2; exit 2;; esac
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
tool="$self/../../tools/fault/d6fs-fault-write-v1.py"
work="$TMPDIR/daimos-d6fs-fault-link-20261012-v1-${FAULT_LOGICAL}-$$"
mkdir -p "$work"
build="$work/image"
out="$build/system/boot/pdp6"
source="$out/kcore-asm/fs_backing.s"
common="BUILD_ROOT=$build PDP10_PREFIX=$PDP10_PREFIX HOST_TOOLS=${DAIMOS_HOST_TOOLS:-$PDP10_PREFIX/bin} DAS_REPO=${DAS_REPO:-$DAIMOS_REPO/../das} KCC_REPO=${KCC_REPO:-$DAIMOS_REPO/../kcc} PDP10_KCC=$PDP10_PREFIX/bin/kcc DSH_IMAGE_LIMIT=${DSH_IMAGE_LIMIT:-037000}"
# Explicit prebuild creates generated KCORE assembler; never modify tree source.
# The normal image build then assembles the test-only replacement.
make -C "$DAIMOS_REPO/system/boot/pdp6" "$out/.kcore-built" $common > "$work/prebuild.log" 2>&1 || { tail -35 "$work/prebuild.log" >&2; exit 1; }
python3 "$tool" "$source" "$work/fs_backing.fault.s" --logical "$FAULT_LOGICAL"
cp "$work/fs_backing.fault.s" "$source"
# Confirm that the generated file, not the pristine kernel input, is assembled.
host_tools="${DAIMOS_HOST_TOOLS:-$PDP10_PREFIX/bin}"
PATH="$host_tools:$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image $common \
 MKBOOTBANNER="$host_tools/mkbootbanner" MKDSK="$host_tools/mkdsk" \
 MKD6FS="$host_tools/mkd6fs" P10FOLD="$host_tools/p10fold" \
 BOOT=dsk ROOT=disk ROOTSET=1 > "$work/image.log" 2>&1 || { tail -35 "$work/image.log" >&2; exit 1; }
grep -F 'fs_backing_write_fault_pass:' "$source" >/dev/null
printf 'INJECTED_IMAGE=%s\n' "$out/boot.ini"
printf 'INJECTED_WORK=%s\n' "$work"
