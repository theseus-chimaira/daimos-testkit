#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
tag=daimos-scheduler-multiproc-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
user="$work/user"
out="$work/simh.out"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)

cleanup()
{
        # Diagnostic runs preserve the exact boot image, simulator transcript,
        # and clock trace so a missing quantum can be investigated after HALT.
        if [ "${DAIMOS_SCHED_KEEP_WORK:-0}" != 1 ]; then
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
    -S "$self/daimos-scheduler-multiproc-v1.c" \
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
    PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=5 \
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
if [ "${DAIMOS_SCHED_CLOCK_DIAG:-0}" = 1 ]; then
        # SIMH EXPECT stops the CPU immediately at each guest sentinel; read
        # proc_timer_clock at the sentinel and the first two scheduling
        # checkpoints.  This is a diagnostic, never the acceptance path.
        clock_addr=$(awk '$1 == "proc_timer_clock" { print $2; exit }' \
            "$boot/kcore.map")
        if [ -z "$clock_addr" ]; then
                echo "$tag: proc_timer_clock missing from kernel map" >&2
                exit 1
        fi
        simh_ini="$boot/boot.headless-clock-v54.ini"
        sed '/^go 020$/,$d' "$boot/boot.headless-rate-v57.ini" > "$simh_ini"
        cat >> "$simh_ini" <<EOF
set debug $work/simh-clock-v54.log
set cpu debug=CONO
expect "<"
go 020
examine $clock_addr
expect "A"
go
examine $clock_addr
expect "b"
go
examine $clock_addr
go
exit
EOF
        printf '%s: clock address %s, diagnostics %s\n' \
            "$tag" "$clock_addr" "$work" >&2
fi
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

text=$(tr -d '\r\n' <"$out")
case "$text" in
*'<'*) text=${text#*<} ;;
*)
        cat "$out" >&2
        echo "$tag: scheduler test sentinel missing" >&2
        exit 1
        ;;
esac
text=${text%%HALT*}
case "$text" in
*'!'*|*'N'*|*'F'*|*'X'*)
        cat "$out" >&2
        echo "$tag: target process reported failure" >&2
        exit 1
        ;;
esac

pos()
{
        expr "$text" : ".*$1" >/dev/null 2>&1 || true
        printf '%s\n' "$text" | awk -v c="$1" '{ p=index($0,c); print p }'
}

pa=$(pos a)
pb=$(pos b)
pc=$(pos c)
pd=$(pos d)
pe=$(pos e)
pA=$(pos A)
pD=$(pos D)
p1=$(pos 1)
p2=$(pos 2)
p3=$(pos 3)
p4=$(pos 4)
p5=$(pos 5)

for p in "$pa" "$pb" "$pc" "$pd" "$pe" "$pA" "$pD" "$p1" "$p2" "$p3" "$p4" "$p5"; do
        if [ "$p" -eq 0 ]; then
                cat "$out" >&2
                echo "$tag: required scheduler marker missing" >&2
                exit 1
        fi
done

# Slot 1 starts first and then burns CPU.  Other users must run before its
# first long-loop checkpoint, otherwise target timer preemption did not occur.
if [ "$pb" -ge "$pA" ] || [ "$pc" -ge "$pA" ] || [ "$pd" -ge "$pA" ] || [ "$pe" -ge "$pA" ]; then
        cat "$out" >&2
        echo "$tag: timer preemption did not run all boot users" >&2
        exit 1
fi

# The disk probe must return after a kernel sleep/wakeup cycle while other
# runnable users exist.
if [ "$pD" -le "$pb" ]; then
        cat "$out" >&2
        echo "$tag: disk sleep/wakeup marker ordering invalid" >&2
        exit 1
fi

# Nice ordering and equal-priority selection are deterministic scheduler-policy
# properties covered by mm-v1.  Do not infer them from completion order here:
# on a fast host simulator a short checkpoint loop can finish within one 60 Hz
# target quantum.  This real-target regression instead verifies actual timer
# preemption, process-private context preservation and disk sleep/wakeup.

printf '%s\n' "$tag: PASS (preemption, process context, nice ABI, sleep/wakeup)"
