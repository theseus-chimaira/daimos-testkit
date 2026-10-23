#!/bin/sh
# Isolated native PDP-6 APR hardware test; NOT an EXEC/RUN XIP launch.
set -eu
: "${TMPDIR:?}"
: "${PDP10_PREFIX:?}"
: "${DAIMOS_REPO:?}"
: "${AAP_PDP6_REPO:?}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work="$TMPDIR/daimos-xip-user-apr-v209-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
p10run="$PDP10_PREFIX/bin/p10run"
kernel="$DAIMOS_REPO/system/kernel"
inc="$kernel/fs"
aap="$AAP_PDP6_REPO/emu/pdp6_headless_v1"
test -x "$aap" || make -C "$AAP_PDP6_REPO/emu" pdp6_headless_v1
"$cc" -std=c99 -Os -DXIP_USER_APR_TEST_V209 -I"$PDP10_PREFIX/include" \
    -I"$inc" -I"$kernel/mm" -I"$kernel/storage" -I"$kernel/core" \
    -S "$here/test.c" -o "$work/test.s"
"$p10run" --machine pdp6 --mode rim --exec-mode step --step-limit 1 --timeout 15 \
    --workdir "$work/run" --name daimos-xip-user-apr-v209 \
    "$here/start-user-v209.s" "$work/test.s" \
    "$inc/memfs_data_pdp6.s" "$inc/memfs_runtime.s" \
    "$here/fs-helpers.s" "$kernel/core/ret.s"
map="$work/run/daimos-xip-user-apr-v209.map"
rim="$work/run/daimos-xip-user-apr-v209.rim"
pool=$(awk '$1 == "xip_pool" {print $2; exit}' "$map")
test -n "$pool" || { echo 'xip_pool symbol missing' >&2; exit 1; }
# Physical pointer is 02000-word aligned by the MEMFS test MM stub.
pool_dec=$(printf '%d' "0$pool")
base=$(( (pool_dec + 1023) / 1024 * 1024 ))
marker=$(printf '%o' "$((base + 24))")
base_symbol=$(awk '$1 == "daimos_memfs_xip_user_base_v209" {print $2; exit}' "$map")
result_symbol=$(awk '$1 == "daimos_memfs_pdp6_result" {print $2; exit}' "$map")
start_symbol=$(awk '$1 == "_start" {print $2; exit}' "$map")
echo "v209 layout: _start=$start_symbol xip_pool=$pool base=$(printf '%o' "$base") result=$result_symbol"
(
    cd "$work"
    {
        printf 'load -r %s\n' "$rim"
        printf '%s\n' 'power on'
        printf 'examine 0%s\n' "$start_symbol"
        sleep 1
        printf 'start 0%s\n' "$start_symbol"
        sleep 12
        printf 'examine 0%s\n' "$marker"
        printf 'examine 0%s\n' "$base_symbol"
        printf 'examine 0%s\n' "$result_symbol"
        printf 'examine 0%s\n' "$(printf '%o' "$((base + 16))")"
        printf 'examine 0%s\n' "$(printf '%o' "$((base + 17))")"
        printf '%s\n' quit
    } | timeout 35 "$aap"
) >"$work/aap.out" 2>&1 || {
    cat "$work/aap.out" >&2
    exit 1
}
if ! grep -Eq "^[>[:space:]]*0*$marker: +0*1234$" "$work/aap.out"; then
    cat "$work/aap.out" >&2
    echo 'AAP user APR did not execute MEMFS-backed store' >&2
    exit 1
fi
if ! grep -Eq "^[>[:space:]]*0*$base_symbol: +0*$(printf '%o' "$base")$" "$work/aap.out" ||
   ! grep -Eq "^[>[:space:]]*0*$result_symbol: +0+$" "$work/aap.out"; then
    cat "$work/aap.out" >&2
    echo 'AAP MEMFS admission or published base inconsistent' >&2
    exit 1
fi
echo 'PASS v209 PDP-6 user APR fetch/store into test-only MEMFS backing'
