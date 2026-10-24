#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
tag=daimos-mm-256k-peak-probe-v267
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
out="$work/simh.out"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)

cleanup()
{
        # Optionally retain the isolated 256K boot image and simulator transcript.
        if [ "${DAIMOS_MM_OBSERVE_KEEP_WORK:-0}" != 1 ]; then
                rm -rf "$work"
        fi
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$user"
cc=${PDP10_GCC:-$PDP10_PREFIX/bin/pdp10-dec-none-gcc}
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"

"$cc" -std=c99 -Os \
    -I"$DAIMOS_REPO/system/kernel/boot" \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/drivers" \
    -I"$DAIMOS_REPO/system/kernel/fs" \
    -I"$DAIMOS_REPO/system/kernel/mm" \
    -I"$DAIMOS_REPO/system/kernel/modules" \
    -I"$DAIMOS_REPO/system/kernel/proc" \
    -I"$DAIMOS_REPO/system/kernel/storage" \
    -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-mm-256k-concurrency-v265.c" \
    -o "$user/init.s"
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

PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build/system/boot/pdp6" \
    PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=${DAIMOS_MM_CONCURRENCY_COUNT:-63} \
    BOOT_PROFILE=full BOOT_CORE_WORDS=01000000 SIMH_CPU_KWORDS=256 COMPILER=gcc \
    SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null

boot="$build/system/boot/pdp6"
dcs_port=$((30000 + ($$ % 10000)))
ge_port=$((45000 + ($$ % 10000)))
"$self/../lib/daimos-simh-headless.sh" "$boot/boot.ini" \
    "$boot/boot.headless.ini" "$dcs_port" "$ge_port"
# A four-tick (60 Hz) preemption test needs real elapsed clock time.  SIMH
# otherwise runs at unrestricted host speed, which can finish BURN_LONG
# before a quantum passes and falsely report that the scheduler failed.
# Limit this one timing-sensitive test to 8M instructions/second: still
# thirty-two times the approximately 0.25 MIPS physical PDP-6, but slow
# enough for the fixed CPU-bound work to span multiple clock quanta.
# Preserve all guest-side scheduling, context, and I/O assertions.
sched_rate=${DAIMOS_SCHED_SIMH_RATE:-8M}
sched_timeout=${DAIMOS_SCHED_SIMH_TIMEOUT:-90}
case "$sched_timeout" in
*[!0-9]*|'')
        echo "$tag: invalid scheduler SIMH timeout: $sched_timeout" >&2
        exit 2 ;;
esac
simh_ini="$boot/boot.headless-rate-v57.ini"
if [ "$sched_rate" = unthrottled ]; then
        cp "$boot/boot.headless.ini" "$simh_ini"
else
        case "$sched_rate" in
        *[!0-9KM]*|'')
                echo "$tag: invalid scheduler SIMH rate: $sched_rate" >&2
                exit 2 ;;
        esac
        awk -v rate="$sched_rate" '
            /^go 020$/ { print "set throttle " rate }
            { print }
        ' "$boot/boot.headless.ini" > "$simh_ini"
fi
# Sample every insertion attempt with SIMH's execution breakpoint action.
# No extra KCORE memory or compiler instrumentation is needed.
insert_addr=$(awk '$1 == "mm_extent_insert" { print $2; exit }' "$boot/kcore.map")
extent_addr=$(awk '$1 == "mm_extent_count" { print $2; exit }' "$boot/kcore.map")
capacity_addr=$(awk '$1 == "mm_extent_capacity" { print $2; exit }' "$boot/kcore.map")
[ -n "$insert_addr" ] && [ -n "$extent_addr" ] && [ -n "$capacity_addr" ] || exit 1
simh_ini="$boot/boot.mm-peak-probe-v267.ini"
sed '/^go 020$/,$d' "$boot/boot.headless-rate-v57.ini" > "$simh_ini"
cat >> "$simh_ini" <<EOF
break $insert_addr;examine $extent_addr;go
go 020
examine $capacity_addr
exit
EOF

set +e
(
        cd "$boot"
        TERM=dumb timeout -k 2s "${sched_timeout}s" stdbuf -o0 -e0 \
            "$PDP10_PREFIX/bin/pdp6" "$simh_ini"
) >"$out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
        cat "$out" >&2
        echo "$tag: simulator failed: $rc" >&2
        exit 1
fi

# Each guest writes three-character tokens: [HH] at start, {HH} at
# completion.  Hex slot identifiers remain unique at 63 processes.
count=${DAIMOS_MM_CONCURRENCY_COUNT:-63}
case "$count" in 48|63) : ;; *) echo "$tag: count must be 48 or 63" >&2; exit 2 ;; esac
text=$(tr -d '\r\n' < "$out")
case "$text" in *'<'*) text=${text#*<} ;; *) echo "$tag: no start marker" >&2; exit 1 ;; esac
case "$text" in *'!'*|*'@'*) echo "$tag: guest failure" >&2; exit 1 ;; esac
for slot in $(seq 1 "$count"); do
    hex=$(printf '%02X' "$slot")
    case "$text" in *"[$hex]"*) : ;; *) echo "$tag: missing start [$hex]" >&2; exit 1 ;; esac
    case "$text" in *"{$hex}"*) : ;; *) echo "$tag: missing finish {$hex}" >&2; exit 1 ;; esac
done
# Every entry breakpoint samples the count BEFORE insertion. The sole
# production MM increment is the AOS at mm_extent_insert_copy; therefore
# a successful insertion can raise occupancy by at most one from here.
# The observed 132-descriptor point sample supplies the lower bound.
short_addr=$(printf '%s' "$extent_addr" | sed 's/^0*//')
short_capacity=$(printf '%s' "$capacity_addr" | sed 's/^0*//')
grep -oE '[0-7]{4,7}:[[:space:]]+[0-7]{12}' "$out" > "$work/mm-raw-v267.txt" || exit 1
grep -E "^0*${short_addr}:[[:space:]]+[0-7]{12}" "$work/mm-raw-v267.txt" > "$work/mm-counts-v267.txt"
grep -E "^0*${short_capacity}:[[:space:]]+[0-7]{12}" "$work/mm-raw-v267.txt" > "$work/mm-capacity-v267.txt"
[ -s "$work/mm-counts-v267.txt" ] && [ -s "$work/mm-capacity-v267.txt" ] || exit 1
python3 - "$work/mm-counts-v267.txt" <<'PYPROBE'
import sys
values = [int(line.split()[1], 8) for line in open(sys.argv[1])]
peak_upper = max(values) + 1
assert peak_upper <= 136, "descriptor capacity exceeded"
assert peak_upper == 132, "unexpected maximum: re-evaluate measured bound"
print("insertion pre-max: %d; proven peak: %d; insertion entries: %d" % (max(values), peak_upper, len(values)))
PYPROBE
cat "$work/mm-capacity-v267.txt"
printf '%s\n' "$tag: PASS ($count processes with insertion-point trace)"
