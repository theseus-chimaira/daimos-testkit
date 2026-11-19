#!/bin/sh
# Source-built 48K PURE fault guest with unmodified fixed KCORE.
set -eu
: "${DAIMOS_REPO:?set the original PURE development source checkout}"
: "${V1677_VARIANT:?general or strict}"
: "${V1677_BASE:?versioned absolute working output directory}"
: "${V1677_FIXTURE:?source-linked v1674 deterministic pipe fixture}"
case "$V1677_VARIANT" in
    general) strict=0 ;;
    strict) strict=1 ;;
    *) echo 'FAIL v1677: unknown build variant' >&2; exit 2 ;;
esac
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$V1677_BASE"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
source="$DAIMOS_REPO/system/kernel/proc/proc_pure_service_pdp6_v1612.c"
fault="$V1677_BASE/proc-pure-service-inject-v1677.c"
build="$V1677_BASE/$V1677_VARIANT-build"
python3 "$here/make-service-fault-v1677.py" "$source" "$fault"
# Source-variable is interpreted relative to the ORIGINAL kernel
# Makefile, even though our source lives under a separate test directory.
relative=$(python3 - "$fault" "$DAIMOS_REPO/system/kernel" <<'PYV1677REL'
import os
import sys
print(os.path.relpath(sys.argv[1], sys.argv[2]))
PYV1677REL
)
for f in "$V1677_FIXTURE/v1673-test-init.dxr" \
         "$V1677_FIXTURE/v1673-test-sleep.dxr"; do
    test -s "$f"
done
make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" \
    ROOT=tape BOOT=dtc BOOT_PROFILE=lowmem COMPILER=gcc \
    BOOT_CORE_WORDS=0200000 SIMH_CPU_KWORDS=64 \
    TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
    DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_PBM_V1667=0 \
    DAIMOS_SWAPLESS_ONLY_V1668="$strict" \
    DAIMOS_VM_PURE_SERVICE_SOURCE="$relative" \
    SYSTEM_INIT_DXR="$V1677_FIXTURE/v1673-test-init.dxr" \
    SYSTEM_MOUNTALL_DXR="$V1677_FIXTURE/v1673-test-sleep.dxr" \
    >"$V1677_BASE/$V1677_VARIANT-build.log" 2>&1 || {
    tail -90 "$V1677_BASE/$V1677_VARIANT-build.log" >&2
    exit 1
}
grep -q '^v1677_fault_return_count[[:space:]]' \
    "$build/pure-mres-v1612.map" || {
    echo 'FAIL v1677: injected MRES counter not linked' >&2
    exit 1
}
if [ -n "${V1677_CONTROL_KCORE:-}" ]; then
    cmp "$build/kcore.dxr" "$V1677_CONTROL_KCORE" || {
        echo 'FAIL v1677: fault experiment changed fixed KCORE' >&2
        exit 1
    }
fi
echo "PASS v1677 source-built $V1677_VARIANT fault image: $build"
sha256sum "$build/kcore.dxr" "$build/pure-mres-v1612.dxr"
