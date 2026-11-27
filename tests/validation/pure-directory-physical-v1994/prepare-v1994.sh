#!/bin/sh
# Rebuild the v1987 guest and v1993 dirty DROP profile from source.
# No historical TMPDIR build is required.
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export PATH="$PDP10_PREFIX/bin:$PATH"
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")/../pure-directory-lifecycle-v1987" && pwd)
work=$(mktemp -d "$TMPDIR/pure-directory-physical-build-v1994.XXXXXX")
trap 'echo "v1994 build evidence: $work"' EXIT
b=$work/build
mkdir -p "$work/user"
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
link="$work/dlink-v1994"
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -o "$link" "$DAIMOS_REPO/tools/host/dlink.c" "$DAIMOS_REPO/tools/host/dobj.c"
# DAIMOS has a different AUXSTORE format/confirmation CLI from the
# standalone pdp10-tools package. Use the actual DAIMOS media producer
# for its own image, without replacing the shared installed utility.
media_tools="$work/host/tools/host"
make -s -C "$DAIMOS_REPO/tools/host" BUILD_ROOT="$work/host" \
    "$media_tools/mkauxstore" "$media_tools/mkdtfs"
incs="-I$DAIMOS_REPO/userland/libc"
for dir in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
for part in guest post; do
    source="$here/$part-v1987.c"
    if [ "$part" = guest ]; then
        source="$(dirname "$0")/guest-v1994.c"
    fi
    "$cc" -std=c99 -Os $incs -S "$source" -o "$work/user/$part.s"
    "$das" -C -F -O "$work/user/$part.dobj" "$work/user/$part.s"
done
for part in crt0 syscall; do
    "$das" -C -F -O "$work/user/$part.dobj" "$DAIMOS_REPO/userland/libc/$part.s"
done
libgcc=$("$cc" -print-libgcc-file-name)
for mode in init marked post; do
    opt=; part=guest
    case $mode in marked) opt=--compressible-mutable;; post) part=post;; esac
    "$link" --pure $opt -b 020 -o "$work/user/$mode.dxr" -M "$work/user/$mode.map" \
        "$work/user/crt0.dobj" "$work/user/syscall.dobj" "$work/user/$part.dobj" "$libgcc"
done
echo "v1994: building strict 64K directory+idle image in $work"
make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$b" PDP10_PREFIX="$PDP10_PREFIX" ROOT=tape BOOT=dtc MKAUXSTORE="$media_tools/mkauxstore" MKDTFS="$media_tools/mkdtfs" \
    BOOT_PROFILE=lowmem COMPILER=gcc BOOT_CORE_WORDS=0200000 \
    SIMH_CPU_KWORDS=64 TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
    DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_SWAPLESS_ONLY_V1668=1 \
    DAIMOS_PBM_DIRECTORY_V1983=1 DAIMOS_PBM_IDLE_RECOVER_V1990=1 DAIMOS_PBM_DIRTY_DROP_V1993=1 \
    SYSTEM_INIT_DXR="$work/user/init.dxr" >"$work/build.log" 2>&1 || {
    tail -80 "$work/build.log"; exit 1;
}
"$b/d6block-v1464" -x "$work/user/marked.dxr" "$work/user/comp.dxr"
cp "$b/tsfs-root.manifest" "$work/tsfs.manifest"
printf 'F /SYSTEM/COMP %s 0555 0 0\nF /SYSTEM/POST %s 0555 0 0\n' \
    "$work/user/comp.dxr" "$work/user/post.dxr" >>"$work/tsfs.manifest"
"$b/mktsfs-v1461" -n 3 -i 1:1 -g 1 -m "$work/tsfs.manifest" \
    -b "$b/kinit.lowmem.words" -o "$work/root-v1994"
"$b/tsfscheck-v1461" "$work/root-v1994"0.dta "$work/root-v1994"1.dta "$work/root-v1994"2.dta
for i in 0 1 2; do cp "$work/root-v1994$i.dta" "$b/media/dtc$i.tap"; done
sha256sum "$work/user/init.dxr" "$work/user/comp.dxr" "$work/user/post.dxr" \
    "$b/kcore.dxr" "$b/pure-mres-v1612.dxr"
printf 'V1994_BUILD=%s\n' "$b"
