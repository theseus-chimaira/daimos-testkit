#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${DAS_REPO:?DAS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-mm-swap-stack-bounds-v294
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
    -S "$self/daimos-mm-swap-postinit-v283.c" -o "$user/init.s"
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
extent_addr=$(awk '$1=="mm_extent_count" {print $2;exit}' "$boot/kcore.map")
capacity_addr=$(awk '$1=="mm_extent_capacity" {print $2;exit}' "$boot/kcore.map")
insert_addr=$(awk '$1=="mm_extent_insert" {print $2;exit}' "$boot/kcore.map")
[ -n "$extent_addr" ] && [ -n "$capacity_addr" ] && [ -n "$insert_addr" ] || exit 1
simh_ini="$boot/boot.mm-swap-highwater-v279.ini"
sed '/^go 020$/,$d' "$boot/boot.headless.ini" > "$simh_ini"
printf 'break %s;examine %s;go\n' "$insert_addr" "$extent_addr" >> "$simh_ini"
slot_addr=$(awk '$1=="proc_current_slot" {print $2;exit}' "$boot/kcore.map")
sched_addr=$(awk '$1=="proc_sched_cursor" {print $2;exit}' "$boot/kcore.map")
[ -n "$slot_addr" ] && [ -n "$sched_addr" ] || exit 1
for sym in proc_swap_out proc_swap_in proc_swap_service_one proc_swap_reclaim proc_swap_victim mm_alloc_aligned mm_compact backstore_read backstore_write; do
    pc=$(awk -v x="$sym" '$1==x {print $2;exit}' "$boot/kcore.map")
    [ -n "$pc" ] || exit 1
    printf 'break %s;examine %s;examine %s;examine 1;examine 17;examine 24722;examine 24772;examine 25046-25120;go\n' "$pc" "$slot_addr" "$sched_addr" >> "$simh_ini"
done
printf 'examine %s\ngo 020\nexit\n' "$capacity_addr" >> "$simh_ini"
set +e
(
        cd "$boot"
        TERM=dumb timeout -k 2s 300s stdbuf -o0 -e0 \
            "$PDP10_PREFIX/bin/pdp6" "$simh_ini"
) >"$out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
        cat "$out" >&2
        echo "$tag: simulator failed: $rc" >&2
        exit 1
fi

# Three complete pressured swap/reclaim and wait/reap cycles must finish.
text=$(tr -d '\r\n' < "$out")
case "$text" in
*'<'*'w'*'Q'*'HALT'*)
    printf '%s\n' "$tag: PASS (one post-INIT 16-child pressure cycle)" ;;
*)
    cat "$out" >&2
    echo "$tag: pressure or resumed writer failed" >&2
    exit 1 ;;
esac

# SIMH strips leading address zeros; normalize both map and printed forms.
# Keep the full trace for independent review after the workdir is removed.
cp "$out" "$TMPDIR/daimos-mm-swap-stack-bounds-v294-transcript.log"
peak=$(grep -oE '[0-7]{4,7}:[[:space:]]+[0-7]{12}' "$out" | \
    awk -v target="$extent_addr" '
        BEGIN { sub(/^0+/, "", target); samples=0; peak=0 }
        { addr=$1; sub(/:$/, "", addr); sub(/^0+/, "", addr);
          if (addr!=target) next;
          oct=$2; n=0; for(i=1;i<=length(oct);i++) n=n*8+substr(oct,i,1);
          samples++; if(n>peak) peak=n }
        END { if(samples==0) exit 3; printf "%d %d\n", peak+1, samples }
    ') || { echo "$tag: no MM breakpoint observations" >&2; exit 1; }
set -- $peak
[ "$1" -le 136 ] && [ "$1" -ge 8 ] || {
    echo "$tag: descriptor peak outside 8..136: $1" >&2; exit 1;
}
printf '%s\n' "$tag: descriptor peak $1 / 136 from $2 insertion samples"
