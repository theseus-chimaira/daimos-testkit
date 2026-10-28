#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-date-race-v612
: "${WALL_CLOCK_HZ:?choose 50 or 60}"
case "$WALL_CLOCK_HZ" in 50|60) ;; *) exit 2 ;; esac
work=$TMPDIR/$tag-$$
build=$work/build
user=$work/user
out=$work/simh.out
clean=$work/simh.clean
src=$(CDPATH= cd -- "$(dirname "$0")" && pwd)/daimos-date-race-v612.c
cc=$PDP10_PREFIX/bin/pdp10-dec-none-gcc
das=$PDP10_PREFIX/bin/das
dlink=$PDP10_PREFIX/bin/dlink
simh=${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}

cleanup()
{
        if [ "${test_passed:-0}" -eq 1 ]; then
                rm -rf "$work"
        else
                echo "$tag: retained failed boot image and media at $work" >&2
        fi
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$user"

"$cc" -std=c99 -Os -DWALL_CLOCK_HZ="$WALL_CLOCK_HZ" \
    -I"$DAIMOS_REPO/system/kernel/boot" \
    -I"$DAIMOS_REPO/system/kernel/core" \
    -I"$DAIMOS_REPO/system/kernel/drivers" \
    -I"$DAIMOS_REPO/system/kernel/fs" \
    -I"$DAIMOS_REPO/system/kernel/mm" \
    -I"$DAIMOS_REPO/system/kernel/modules" \
    -I"$DAIMOS_REPO/system/kernel/proc" \
    -I"$DAIMOS_REPO/system/kernel/storage" \
    -I"$DAIMOS_REPO/userland/libc" \
    -S "$src" -o "$user/init.s"
"$das" -C -F -O "$user/init.dobj" "$user/init.s"
"$das" -C -F -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
libgcc=$($cc -print-libgcc-file-name)
"$dlink" -b 020 -o "$user/init.dxr" -M "$user/init.map" \
    "$user/crt0.dobj" "$user/syscall.dobj" "$user/init.dobj" "$libgcc"

PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 WALL_CLOCK_HZ="$WALL_CLOCK_HZ" \
    SYSTEM_INIT_DXR="$user/init.dxr" >/dev/null
boot=$build/system/boot/pdp6
# DEC Type 340 is unrelated to clock verification and SDL windows can crash.
sed -i "s/^set dpy window$/set dpy HEADLESS/; s/^set dpy enabled$/set dpy disabled/" "$boot/boot.ini"

# A prior system boot can change mounted D6FS and auxiliary media.
# Restore the exact post-build baseline before *each* independent run.
mkdir -p "$work/pristine"
cp -a "$boot/disk" "$boot/drum" "$boot/media" "$work/pristine/"
for mode in disabled enabled; do
        cp -a "$work/pristine/disk/." "$boot/disk/"
        cp -a "$work/pristine/drum/." "$boot/drum/"
        cp -a "$work/pristine/media/." "$boot/media/"
        # The image is identical in both runs. Only the simulated PCLK differs.
        case "$mode" in
        enabled) expected='#T#' ;;
        disabled) expected='#Z#' ;;
        esac
        sed -i "s/^set pclk enabled$/set pclk $mode/; s/^set pclk disabled$/set pclk $mode/" "$boot/boot.ini"
        set +e
        (cd "$boot" && TERM=dumb timeout -k 2s 45s stdbuf -o0 -e0 "$simh" boot.ini) >"$out" 2>&1
        rc=$?
        set -e
        if [ "$rc" -ne 0 ]; then
                cat "$out" >&2
                echo "$tag: $mode simulator failed ($rc)" >&2
                exit 1
        fi
        tr -d '\r\n' < "$out" > "$clean"
        if ! grep -Fq "$expected" "$clean"; then
                cat "$out" >&2
                echo "$tag: missing $mode $expected marker" >&2
                exit 1
        fi
done
test_passed=1
printf '%s\n' "$tag: PASS (multiprocess UTC GETTIME SETTIME)"
