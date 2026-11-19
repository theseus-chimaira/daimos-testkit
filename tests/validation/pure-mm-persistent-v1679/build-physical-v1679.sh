#!/bin/sh
# Copy a clean original PURE source tree to test scratch, inject ONLY
# its optional MRES DROP source, and construct an original 48K guest.
set -eu
: "${DAIMOS_REPO:?original PURE source checkout required}"
: "${V1679_BASE:?absolute versioned scratch directory required}"
: "${V1679_FIXTURE:?exact v1674 pipe fixture required}"
: "${V1679_VARIANT:?general or strict required}"
case "$V1679_VARIANT" in
    general) strict=0 ;;
    strict) strict=1 ;;
    *) echo 'FAIL v1679: invalid profile' >&2; exit 2 ;;
esac
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
# A disposable source copy is not next to the normal DevSpace2 das/kcc
# checkout aliases. Use the exact current external source repos rather
# than leaving a broken relative-include/make dependency.
KCC_REPO=${KCC_REPO:-$HOME/git/kcc}
DAS_REPO=${DAS_REPO:-$HOME/git/das}
export TMPDIR PDP10_PREFIX
for f in "$KCC_REPO/Makefile" "$DAS_REPO/Makefile"; do
    test -s "$f" || { echo "FAIL v1679: missing build dependency $f" >&2; exit 1; }
done
mkdir -p "$V1679_BASE"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
scratch="$V1679_BASE/source-copy-v1679"
if [ ! -d "$scratch/system/kernel" ]; then
    mkdir -p "$scratch"
    # Source copy is isolated from the production branch. Strip the
    # original linked .git metadata to prevent accidental source push.
    (cd "$DAIMOS_REPO" && tar -cf - .) | (cd "$scratch" && tar -xf -)
    rm -rf "$scratch/.git"
fi
source="$DAIMOS_REPO/system/kernel/proc/proc_pure_ram_v1381.c"
copy="$scratch/system/kernel/proc/proc_pure_ram_v1381.c"
python3 "$here/make-physical-fault-v1679.py" "$source" "$copy"
build="$V1679_BASE/$V1679_VARIANT-build"
for f in "$V1679_FIXTURE/v1673-test-init.dxr" \
         "$V1679_FIXTURE/v1673-test-sleep.dxr"; do
    test -s "$f"
done
make -s -C "$scratch/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" \
    KCC_REPO="$KCC_REPO" DAS_REPO="$DAS_REPO" \
    ROOT=tape BOOT=dtc BOOT_PROFILE=lowmem COMPILER=gcc \
    BOOT_CORE_WORDS=0200000 SIMH_CPU_KWORDS=64 \
    TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
    DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_PBM_V1667=0 \
    DAIMOS_SWAPLESS_ONLY_V1668="$strict" \
    SYSTEM_INIT_DXR="$V1679_FIXTURE/v1673-test-init.dxr" \
    SYSTEM_MOUNTALL_DXR="$V1679_FIXTURE/v1673-test-sleep.dxr" \
    >"$V1679_BASE/$V1679_VARIANT-build.log" 2>&1 || {
    tail -90 "$V1679_BASE/$V1679_VARIANT-build.log" >&2
    exit 1
}
grep -q '^v1679_rebase_fault_count[[:space:]]' \
    "$build/pure-mres-v1612.map" || {
    echo 'FAIL v1679: missing real MM fault witness' >&2
    exit 1
}
if [ -n "${V1679_CONTROL_KCORE:-}" ]; then
    cmp "$build/kcore.dxr" "$V1679_CONTROL_KCORE" || {
        echo 'FAIL v1679: test modified fixed KCORE' >&2; exit 1;
    }
fi
echo "PASS v1679 $V1679_VARIANT source-linked 48K physical build: $build"
sha256sum "$build/kcore.dxr" "$build/pure-mres-v1612.dxr"
