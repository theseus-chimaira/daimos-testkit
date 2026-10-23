#!/bin/sh
# Execute the production MEMFS allocator's native reservation tests on AAP.
set -eu
: "${TMPDIR:?TMPDIR is required}"
: "${PDP10_PREFIX:?PDP10_PREFIX is required}"
: "${DAIMOS_REPO:?DAIMOS_REPO is required}"
: "${AAP_PDP6_REPO:?AAP_PDP6_REPO is required}"

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work="$TMPDIR/daimos-memfs-xip-aap-v202-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
p10run="$PDP10_PREFIX/bin/p10run"
kernel="$DAIMOS_REPO/system/kernel"
inc="$kernel/fs"
mm="$kernel/mm"
storage="$kernel/storage"
aap="$AAP_PDP6_REPO/emu/pdp6_headless_v1"

test -x "$aap" || make -C "$AAP_PDP6_REPO/emu" pdp6_headless_v1
"$cc" -std=c99 -Os -I"$PDP10_PREFIX/include" -I"$inc" -I"$mm" \
    -I"$storage" -I"$kernel/core" -S "$here/test.c" -o "$work/test.s"
awk '/^vm_space_destroy:/{copy=1} /^vm_space_load_file:/{copy=0} copy {print}' \
    "$kernel/proc/vm_pdp6.s" > "$work/vm-destroy-v215.s"
sed -i '1i\        .text\n        .globl vm_space_destroy' "$work/vm-destroy-v215.s"

# The SIMH run also produces the identical executable RIM used by AAP.
"$p10run" --machine pdp6 --mode rim --exec-mode go --timeout 15 \
    --workdir "$work/run" --name daimos-memfs-xip-v202 \
    --expect daimos_memfs_pdp6_result=0 \
    "$here/start.s" "$work/test.s" "$inc/memfs_data_pdp6.s" \
    "$inc/memfs_runtime.s" "$here/fs-helpers.s" \
    "$work/vm-destroy-v215.s" "$kernel/core/ret.s"

result=$(awk '$1 == "daimos_memfs_pdp6_result" {print $2; exit}' \
    "$work/run/daimos-memfs-xip-v202.map")
test -n "$result" || { echo 'AAP: result symbol missing' >&2; exit 1; }

(
    cd "$work"
    {
        printf 'load -r %s\n' "$work/run/daimos-memfs-xip-v202.rim"
        printf '%s\n' 'power on'
        sleep 1
        printf '%s\n' 'start 020'
        sleep 5
        printf 'examine 0%s\n' "$result"
        printf '%s\n' quit
    } | timeout 45 "$aap"
) >"$work/aap.out" 2>&1 || {
    cat "$work/aap.out" >&2
    exit 1
}

if ! grep -Eq "^[>[:space:]]*0*$result: +0+$" "$work/aap.out"; then
    cat "$work/aap.out" >&2
    echo 'AAP native MEMFS XIP pin regression failed' >&2
    exit 1
fi
echo 'PASS daimos-memfs-xip-v202 on AAP PDP-6'
