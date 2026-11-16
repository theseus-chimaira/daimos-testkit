#!/bin/sh
# Check v1611 default OFF and explicit PURE opt-in from the SAME KCC
# build directory, so stale KINIT stamps and resident KCORE growth
# cannot hide behind separately built images.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/pure-boot-mode-v1611.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" = 1 ]; then echo "v1611 boot work: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM
boot="$DAIMOS_REPO/system/boot/pdp6"

build_mode()
{
    mode=$1
    log="$work/mode-$mode.log"
    if ! make -s -C "$boot" BUILD="$work" ROOT=tape \
        BOOT_PROFILE=full COMPILER=kcc \
        DAIMOS_PURE_MRES_ENABLED="$mode" \
        "$work/kinit.dxr" >"$log" 2>&1; then
        tail -60 "$log" >&2
        exit 1
    fi
    test -s "$work/kinit.dxr"
    test -s "$work/kinit.map"
    test -s "$work/kcore.dxr"
}

build_mode 0
if grep -q '^proc_pure_mres_package_v1611[[:space:]]' "$work/kinit.map"; then
    echo 'FAIL v1611: default KINIT unexpectedly contains PURE' >&2
    exit 1
fi
cp "$work/kcore.dxr" "$work/kcore-original.dxr"
echo 'PASS v1611: default KINIT excludes PURE MRES'

build_mode 1
grep -q '^proc_pure_mres_package_v1611[[:space:]]' "$work/kinit.map" || {
    echo 'FAIL v1611: opt-in KINIT lost PURE MRES package' >&2
    exit 1
}
grep -q '^proc_pure_mres_reclaim_v1611[[:space:]]' \
    "$work/pure-mres-v1611.map"
grep -q '^proc_pure_mres_service_v1611[[:space:]]' \
    "$work/pure-mres-v1611.map"
cmp "$work/kcore-original.dxr" "$work/kcore.dxr" || {
    echo 'FAIL v1611: opt-in changes permanent KCORE' >&2
    exit 1
}
echo 'PASS v1611: opt-in KINIT links PURE, no fixed KCORE growth'

build_mode 0
if grep -q '^proc_pure_mres_package_v1611[[:space:]]' "$work/kinit.map"; then
    echo 'FAIL v1611: PURE package survived same-build disable' >&2
    exit 1
fi
cmp "$work/kcore-original.dxr" "$work/kcore.dxr"
echo 'PASS v1611: same-build disable removes PURE again'
