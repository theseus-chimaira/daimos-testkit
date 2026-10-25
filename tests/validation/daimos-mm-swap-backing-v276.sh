#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${DAS_REPO:?DAS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-mm-swap-backing-v276
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
out="$work/simh.out"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
trap 'rm -rf "$work"' EXIT HUP INT TERM
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
    -S "$self/daimos-mm-swap-pressure-v272.c" -o "$user/init.s"
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
    BOOT_CORE_WORDS=01000000 SIMH_CPU_KWORDS=256 COMPILER=gcc \
    DAS_REPO="$DAS_REPO" \
    SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null

boot="$build/system/boot/pdp6"
dcs_port=$((30000 + ($$ % 10000)))
ge_port=$((45000 + ($$ % 10000)))
"$self/../lib/daimos-simh-headless.sh" "$boot/boot.ini" \
    "$boot/boot.headless.ini" "$dcs_port" "$ge_port"
# Trace admission without modifying permanent code or guest implementation.
# Each breakpoint resumes execution after a single examination.
trace_ini="$boot/boot.swap-exits-v274.ini"
sed '/^go 020$/,$d' "$boot/boot.headless.ini" > "$trace_ini"
for sym in proc_swap_reclaim proc_swap_out backstore_alloc backstore_free proc_storage_publish_v30; do
    addr=$(awk -v name="$sym" '$1==name {print $2; exit}' "$boot/kcore.map")
    [ -n "$addr" ] || exit 1
    printf 'break %s;examine %s;go\n' "$addr" "$addr" >> "$trace_ini"
done
write_addr=$(awk '$1=="backstore_write" {print $2;exit}' "$boot/kcore.map")
[ -n "$write_addr" ] || exit 1
printf 'break %s' "$write_addr" >> "$trace_ini"
for sym in backstore_blocks backstore_blocks_used blockset_direct_tail; do
    addr=$(awk -v name="$sym" '$1==name {print $2; exit}' "$boot/kcore.map")
    [ -n "$addr" ] || exit 1
    printf ';examine %s' "$addr" >> "$trace_ini"
done
printf ';go\n' >> "$trace_ini"
printf '%s\n' 'go 020' 'exit' >> "$trace_ini"
set +e
(
        cd "$boot"
        TERM=dumb timeout -k 2s 60s stdbuf -o0 -e0 \
            "$PDP10_PREFIX/bin/pdp6" "$trace_ini"
) >"$out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
        cat "$out" >&2
        echo "$tag: simulator failed: $rc" >&2
        exit 1
fi

# Negative control: admission succeeds but this workload is too small
# to require a target swap on a 256K system. Do not claim swap PASS.
# Preserve the trace summary even though the workload currently fails.
printf '%s\n' "$tag: native trace:" >&2
grep -E '^Breakpoint, PC:' "$out" | sort | uniq -c >&2 || :
# Expected diagnostic failure; verify live backing-state samples were
# captured at the write breakpoint rather than before guest boot.
text=$(tr -d '\r\n' < "$out")
for sample in '24504:[[:space:]]+000000004000' '24505:[[:space:]]+000000000320' '24716:[[:space:]]+000000002000'; do
    grep -Eq "$sample" "$out" || {
        echo "$tag: missing live backing sample: $sample" >&2
        exit 1
    }
done
case "$text" in
*'<w'*'p7!W'*'HALT'*)
    echo "$tag: PASS (diagnostic: 2048-block backing vs 1024-block tail; swap still fails)" ;;
*) echo "$tag: unexpected guest result" >&2; exit 1 ;;
esac
