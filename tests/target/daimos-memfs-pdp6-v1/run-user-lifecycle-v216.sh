#!/bin/sh
# Native user-mode XIP fetch -> monitor UUO -> production VM teardown.
# Restricted test ABI; not general shared-XIP EXEC/RUN admission.
set -eu
: "${TMPDIR:?}"
: "${PDP10_PREFIX:?}"
: "${DAIMOS_REPO:?}"
: "${AAP_PDP6_REPO:?}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work="$TMPDIR/daimos-memfs-user-lifecycle-v216-$$"
mkdir -p "$work"
trap 'if [ "${XIP_V216_KEEP:-0}" != 1 ]; then rm -rf "$work"; else echo "v216 retained: $work"; fi' EXIT HUP INT TERM
kernel="$DAIMOS_REPO/system/kernel"
inc="$kernel/fs"
aap="$AAP_PDP6_REPO/emu/pdp6_headless_v1"
test -x "$aap" || make -C "$AAP_PDP6_REPO/emu" pdp6_headless_v1
"$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=c99 -Os \
    -DXIP_USER_LIFECYCLE_V216 -I"$PDP10_PREFIX/include" -I"$inc" \
    -I"$kernel/mm" -I"$kernel/storage" -I"$kernel/core" \
    -S "$here/test.c" -o "$work/test.s"
# Extract the actual production VM-destroy body; never duplicate its logic.
awk '/^vm_space_destroy:/{copy=1} /^vm_space_load_file:/{copy=0} copy {print}' \
    "$kernel/proc/vm_pdp6.s" > "$work/vm-destroy-v216.s"
test -s "$work/vm-destroy-v216.s"
sed -i '1i\        .text\n        .globl vm_space_destroy' "$work/vm-destroy-v216.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode rim --start 01000 \
    --exec-mode step --step-limit 1 --timeout 15 --workdir "$work/run" \
    --name daimos-memfs-user-lifecycle-v216 \
    "$here/start-user-lifecycle-v216.s" "$work/test.s" \
    "$inc/memfs_data_pdp6.s" "$inc/memfs_runtime.s" \
    "$here/fs-helpers.s" "$work/vm-destroy-v216.s" "$kernel/core/ret.s"
map="$work/run/daimos-memfs-user-lifecycle-v216.map"
rim="$work/run/daimos-memfs-user-lifecycle-v216.rim"
result=$(awk '$1 == "daimos_memfs_pdp6_result" {print $2; exit}' "$map")
marker=$(awk '$1 == "test_xip_monitor_marker_v216" {print $2; exit}' "$map")
start=$(awk '$1 == "_start" {print $2; exit}' "$map")
test -n "$result" && test -n "$marker" && test -n "$start"
result_match=$(printf '%o' "$((0$result))")
marker_match=$(printf '%o' "$((0$marker))")
# The default p10run script breaks unconditionally at logical PC 020 as an
# infinite-LUUO safety sentinel. Here 020 is our *legitimate user entry* and
# the breakpoint fires before the relocated instruction can be fetched.
# Run this one native test without that sentinel, with its own timeout and
# assertions on the executive-only result and monitor-UUO marker.
cat >"$work/simh-v216.ini" <<EOF
do $PDP10_PREFIX/share/pdp10-tools/simh/pdp6.ini
load $rim
go $start
examine $result
examine $marker
quit
EOF
timeout 20 "$PDP10_PREFIX/bin/pdp6" "$work/simh-v216.ini" \
    >"$work/simh.out" 2>&1 || {
    cat "$work/simh.out" >&2
    exit 1
}
if ! grep -Eq "^0*$result_match:[[:space:]]+0+$" "$work/simh.out" ||
   ! grep -Eq "^0*$marker_match:[[:space:]]+0*1234$" "$work/simh.out"; then
    cat "$work/simh.out" >&2
    echo 'FAIL v216: SIMH non-writing XIP lifecycle failed' >&2
    exit 1
fi
echo 'PASS v216: SIMH user XIP UUO, unchanged image, production VM teardown'
(
    cd "$work"
    {
        printf 'load -r %s\n' "$rim"
        printf '%s\n' 'power on'
        sleep 1
        printf 'start 0%s\n' "$start"
        sleep 6
        printf 'examine 0%s\n' "$result"
        printf 'examine 0%s\n' "$marker"
        printf '%s\n' quit
    } | timeout 35 "$aap"
) >"$work/aap.out" 2>&1 || {
    cat "$work/aap.out" >&2
    exit 1
}
if ! grep -Eq "^[>[:space:]]*0*$result_match: +0+$" "$work/aap.out" ||
   ! grep -Eq "^[>[:space:]]*0*$marker_match: +0*1234$" "$work/aap.out"; then
    cat "$work/aap.out" >&2
    echo 'FAIL v216: AAP user image or VM teardown did not complete' >&2
    exit 1
fi
echo 'PASS v216: AAP user XIP UUO, unchanged image, production VM teardown'
