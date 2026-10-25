#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${DAS_REPO:?DAS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-mm-swap-snapshot-v312
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
out="$work/simh.out"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
trap 'if [ "${DAIMOS_MM_TRACE_KEEP:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
mkdir -p "$user"

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"

"$cc" -std=c99 -Os \
    -I"$DAIMOS_REPO/system/kernel/boot" \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/drivers" \
    -I"$DAIMOS_REPO/system/kernel/fs" \
    -I"$DAIMOS_REPO/system/kernel/ipc" \
    -I"$DAIMOS_REPO/system/kernel/mm" \
    -I"$DAIMOS_REPO/system/kernel/modules" \
    -I"$DAIMOS_REPO/system/kernel/proc" \
    -I"$DAIMOS_REPO/system/kernel/storage" \
    -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-mm-swap-postinit-v311.c" -o "$user/init.s"
"$das" -C -F -O "$user/init.dobj" "$user/init.s"
"$das" -C -F -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$user/init.dxr" -M "$user/init.map" \
    "$user/crt0.dobj" "$user/syscall.dobj" "$user/init.dobj" "$libgcc"

grep -Eq '^_start[[:space:]]+000020$' "$user/init.map" || {
        echo "$tag: test INIT is not linked at logical 020" >&2
        exit 1
}

PATH="$PDP10_PREFIX/bin:$PATH" make \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build/system/boot/pdp6" \
    PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 BOOT_PROFILE=full \
    BOOT_CORE_WORDS=01000000 SIMH_CPU_KWORDS=256 COMPILER=gcc DRUM_BACKSTORE_BLOCKS=012000 \
    DAS_REPO="$DAS_REPO" \
    SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null

boot="$build/system/boot/pdp6"
dcs_port=$((30000 + ($$ % 10000)))
ge_port=$((45000 + ($$ % 10000)))
"$self/../lib/daimos-simh-headless.sh" "$boot/boot.ini" \
    "$boot/boot.headless.ini" "$dcs_port" "$ge_port"
# Capture the first swap-out at entry and just BEFORE state publication.
# The second breakpoint is the publication routine ENTRY, not completion.
# SIMH -m writes an address-tagged snapshot of physical memory without
# injecting any code or allocating guest RAM. Stop at the second event.
simh_ini="$boot/boot.swap-snapshot-v312.ini"
before="$work/swap-before-v312.txt"
after="$work/swap-after-v312.txt"
entry=$(awk '$1=="proc_swap_out" {print $2; exit}' "$boot/kcore.map")
publish=$(awk '$1=="proc_storage_publish_v30" {print $2; exit}' "$boot/kcore.map")
[ -n "$entry" ] && [ -n "$publish" ] || exit 1
sed '/^go 020$/,$d' "$boot/boot.headless.ini" > "$simh_ini"
printf 'break %s;examine 0-777777;go\n' "$entry" >> "$simh_ini"
printf 'break %s;examine 0-777777;exit\n' "$publish" >> "$simh_ini"
printf 'go 020\nexit\n' >> "$simh_ini"
set +e
(cd "$boot" && TERM=dumb timeout -k 2s 900s stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$simh_ini") > "$out" 2>&1
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
    python3 "$self/daimos-mm-swap-snapshot-split-v312.py" "$out" "$entry" "$publish" "$before" "$after" || rc=1
fi
if [ "$rc" -ne 0 ] || [ ! -s "$before" ] || [ ! -s "$after" ]; then
    tail -40 "$out" >&2
    echo "$tag: snapshot capture failed, simulator=$rc" >&2
    exit 1
fi
python3 "$self/daimos-mm-swap-snapshot-compare-v312.py" "$before" "$after" "$boot/kcore.map" | tee "$work/snapshot-diff-v312.txt"
echo "$tag: entry-to-prepublication snapshots compared (diagnostic only)"
