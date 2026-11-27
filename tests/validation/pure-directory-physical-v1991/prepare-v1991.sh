#!/bin/sh
# Source-built strict directory+idle package, identical accepted guest DXRs.
set -eu
: "${DAIMOS_REPO:?}" "${V1987_BUILD:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
old=$(CDPATH= cd -- "$V1987_BUILD/.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-directory-recovery-build-v1991.XXXXXX")
trap 'echo "v1991 build evidence: $work"' EXIT
b=$work/build
for name in init comp post; do test -s "$old/user/$name.dxr"; done
ln -s "$old/user" "$work/user"
make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$b" PDP10_PREFIX="$PDP10_PREFIX" ROOT=tape BOOT=dtc \
    BOOT_PROFILE=lowmem COMPILER=gcc BOOT_CORE_WORDS=0200000 \
    SIMH_CPU_KWORDS=64 TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
    DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_SWAPLESS_ONLY_V1668=1 \
    DAIMOS_PBM_DIRECTORY_V1983=1 DAIMOS_PBM_IDLE_RECOVER_V1990=1 \
    SYSTEM_INIT_DXR="$old/user/init.dxr" >"$work/build.log" 2>&1 || {
    tail -80 "$work/build.log"; exit 1;
}
cp "$b/tsfs-root.manifest" "$work/tsfs.manifest"
printf 'F /SYSTEM/COMP %s 0555 0 0\nF /SYSTEM/POST %s 0555 0 0\n' \
    "$old/user/comp.dxr" "$old/user/post.dxr" >>"$work/tsfs.manifest"
"$b/mktsfs-v1461" -n 3 -i 1:1 -g 1 -m "$work/tsfs.manifest" \
    -b "$b/kinit.lowmem.words" -o "$work/root-v1991"
"$b/tsfscheck-v1461" "$work/root-v1991"0.dta "$work/root-v1991"1.dta "$work/root-v1991"2.dta
for i in 0 1 2; do cp "$work/root-v1991$i.dta" "$b/media/dtc$i.tap"; done
cmp "$b/kcore.dxr" "$V1987_BUILD/kcore.dxr"
sha256sum "$old/user/init.dxr" "$old/user/comp.dxr" "$old/user/post.dxr"
printf 'V1991_BUILD=%s\n' "$b"
