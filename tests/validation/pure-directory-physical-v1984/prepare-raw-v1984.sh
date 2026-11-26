#!/bin/sh
# Same fixture bytes and 64K strict TSFS configuration.
# Default RAW control; v1985 explicit directory placement replay.
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
: "${V1983_BUILD:?original directory fixture build required}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
mkdir -p "$TMPDIR"
profile=${V1985_DIRECTORY:-0}
case $profile in
    0) tag=raw-control-v1984 ;;
    1) tag=placement-control-v1985 ;;
    *) echo 'V1985_DIRECTORY must be 0 or 1' >&2; exit 1 ;;
esac
work=$(mktemp -d "$TMPDIR/pure-directory-$tag.XXXXXX")
trap 'echo "$tag evidence: $work"' EXIT
orig=$(CDPATH= cd -- "$V1983_BUILD/.." && pwd)
b=$work/build
test -s "$orig/user/init.dxr"
test -s "$orig/user/comp.dxr"
make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$b" PDP10_PREFIX="$PDP10_PREFIX" ROOT=tape BOOT=dtc \
    BOOT_PROFILE=lowmem COMPILER=gcc BOOT_CORE_WORDS=0200000 \
    SIMH_CPU_KWORDS=64 TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
    DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_SWAPLESS_ONLY_V1668=1 \
    DAIMOS_PBM_DIRECTORY_V1983="$profile" SYSTEM_INIT_DXR="$orig/user/init.dxr" \
    >"$work/build.log" 2>&1 || { tail -60 "$work/build.log"; exit 1; }
cp "$b/tsfs-root.manifest" "$work/tsfs.manifest"
printf 'F /SYSTEM/COMP %s 0555 0 0\n' "$orig/user/comp.dxr" >>"$work/tsfs.manifest"
"$b/mktsfs-v1461" -n 3 -i 1:1 -g 1 -m "$work/tsfs.manifest" \
    -b "$b/kinit.lowmem.words" -o "$work/root-v1984"
"$b/tsfscheck-v1461" "$work/root-v1984"0.dta "$work/root-v1984"1.dta "$work/root-v1984"2.dta
for unit in 0 1 2; do cp "$work/root-v1984$unit.dta" "$b/media/dtc$unit.tap"; done
if [ "$profile" = 0 ]; then printf 'RAW_BUILD=%s\n' "$b"; else printf 'V1985_BUILD=%s\n' "$b"; fi
