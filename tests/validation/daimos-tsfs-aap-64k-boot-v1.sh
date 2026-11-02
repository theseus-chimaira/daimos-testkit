#!/bin/sh
# Boot a real three-member TSFS root on the AAP PDP-6 with 64K words.
# The separate stage-1 and auxiliary disk-image targets are intentional:
# no D6FS disk is required for this DECtape-root acceptance test.
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${AAP_PDP6_REPO:?AAP_PDP6_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:=$HOME/tmp}"

tag=daimos-tsfs-aap-64k-boot-v1
work="$TMPDIR/$tag-$$"
build=${TSFS_BOOT_BUILD:-$work/build/system/boot/pdp6}
aap=${AAP_EMULATOR:-$AAP_PDP6_REPO/emu/pdp6}
config=${AAP_CONFIG:-/usr/local/share/pdp6-aap-v2/init-full-8dt-v2.ini}
timeout_s=${AAP_BOOT_TIMEOUT:-900}
keep=${AAP_BOOT_KEEP:-0}

mkdir -p "$work" "$work/media" "$work/emu"
cleanup()
{
    if [ "$keep" != 1 ] && [ "$keep" != yes ]; then
        rm -rf "$work"
    else
        printf '%s\n' "$tag: evidence kept at $work"
    fi
}
trap cleanup EXIT HUP INT TERM

test -r "$config" || { echo "$tag: AAP configuration missing: $config" >&2; exit 2; }
if [ ! -x "$aap" ]; then
    make -C "$AAP_PDP6_REPO/emu" pdp6 > "$work/aap-build.log" 2>&1 || {
        tail -35 "$work/aap-build.log" >&2
        exit 1
    }
fi
test -x "$aap" || { echo "$tag: AAP emulator missing: $aap" >&2; exit 2; }

if [ -z "${TSFS_BOOT_BUILD:-}" ]; then
    make -C "$DAIMOS_REPO/tools/host" build \
        BUILD_ROOT="$work/build" > "$work/host-build.log" 2>&1 || {
        tail -35 "$work/host-build.log" >&2
        exit 1
    }
    PATH="$PDP10_PREFIX/bin:$PATH" \
    make -C "$DAIMOS_REPO/system/boot/pdp6" \
        "$build/media/tsfs-root0.dta" "$build/stage1-dtc.pt" \
        BUILD_ROOT="$work/build" PDP10_PREFIX="$PDP10_PREFIX" \
        BOOT_PROFILE=lowmem BOOT_CORE_WORDS=0200000 \
        SIMH_CPU_KWORDS=64 COMPILER=gcc ROOT=tape BOOT=dtc \
        TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
        MONITORFS_MRES_ENABLED=1 \
        MKTSFS="$work/build/tools/host/mktsfs" \
        > "$work/image-build.log" 2>&1 || {
        tail -35 "$work/image-build.log" >&2
        exit 1
    }
fi

for n in 0 1 2; do
    test -s "$build/media/tsfs-root$n.dta" || {
        echo "$tag: missing TSFS member $n" >&2
        exit 1
    }
done
test -s "$build/stage1-dtc.pt" || {
    echo "$tag: missing Stage1 DECtape read-in tape" >&2
    exit 1
}

converter=${DTA2DTR:-$DAIMOS_REPO/build/tools/host/dta2dtr}
if [ -z "${DTA2DTR:-}" ] && [ -x "$work/build/tools/host/dta2dtr" ]; then
    converter="$work/build/tools/host/dta2dtr"
fi
test -x "$converter" || {
    echo "$tag: missing dta2dtr converter: $converter" >&2
    exit 2
}

for n in 0 1 2; do
    drive=$((n + 1))
    "$converter" "$build/media/tsfs-root$n.dta" \
        "$work/media/dx$drive.dtr"
done
truncate -s 591872 "$work/media/blank.dta"
"$converter" "$work/media/blank.dta" "$work/media/blank.dtr"
for drive in 4 5 6 7 8; do
    cp "$work/media/blank.dtr" "$work/media/dx$drive.dtr"
done

# Four 16K physical core modules, not the AAP configuration's default 256K.
# Each 16K module occupies one address selector on the PDP-6 memory bus.
awk '
    $0 == "mkdev mem0 moby mem_0" {
        for (n = 0; n < 4; ++n)
            printf "mkdev mem%d cmem161C mem_%d\n", n, n
        next
    }
    $0 == "connectmem mem0 0 apr 0" {
        for (n = 0; n < 4; ++n)
            printf "connectmem mem%d 0 apr %d\n", n, n
        next
    }
    { print }
' "$config" > "$work/emu/init.ini"

grep -qx 'connectmem mem3 0 apr 3' "$work/emu/init.ini" || {
    echo "$tag: AAP configuration memory substitution failed" >&2
    exit 2
}

for drive in 1 2 3 4 5 6 7 8; do
    printf 'mount dx%d %s\n' "$drive" "$work/media/dx$drive.dtr" \
        >> "$work/emu/init.ini"
done
cat >> "$work/emu/init.ini" <<EOF
mount tty /dev/tty
mount ptr $build/stage1-dtc.pt
switches 02
ptrmotor ptr on
power on
deposit 020 0710600000060
deposit 021 0710740000010
deposit 022 0254000000021
deposit 023 0710440000026
deposit 024 0710740000010
deposit 025 0254000000024
deposit 026 000000000000
deposit 027 0254000000021
start 020
EOF

if [ -d "$(dirname "$config")/art" ]; then
    ln -s "$(dirname "$config")/art" "$work/art"
fi
mkfifo "$work/control.fifo"
(
    cd "$work/emu"
    exec 9<> "$work/control.fifo"
    SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
        timeout --signal=TERM --kill-after=15s "$timeout_s" \
        script -q -f -e -c "'$aap' < '$work/control.fifo'" \
        "$work/console.log" < /dev/null &
    child=$!
    while kill -0 "$child" 2>/dev/null; do
        if [ -r "$work/console.log" ] &&
           { grep -q 'INIT V1' "$work/console.log" ||
             grep -q '?RT' "$work/console.log"; }; then
            printf 'quit\n' >&9
            break
        fi
        sleep 2
    done
    wait "$child"
) > "$work/run.log" 2>&1 || rc=$?

# The guest remains alive after INIT. A timeout is expected; root failure is
# identified by ?RT, not by the host timeout's exit status.
rc=${rc:-0}
if [ "$rc" -ne 0 ] && [ "$rc" -ne 124 ]; then
    tail -35 "$work/run.log" >&2
    echo "$tag: emulator exited unexpectedly ($rc)" >&2
    keep=1
    exit 1
fi

if ! grep -Eq 'MEM[[:space:]]+64 K' "$work/console.log" ||
   ! grep -Eq 'DTC[[:space:]]+OK' "$work/console.log" ||
   ! grep -q 'INIT V1' "$work/console.log" ||
   grep -q '?RT' "$work/console.log"; then
    tail -45 "$work/console.log" >&2
    echo "$tag: failed (64K / DTC / INIT V1 acceptance)" >&2
    keep=1
    exit 1
fi

printf '%s\n' "$tag: PASS (64K AAP, three TSFS members, INIT V1)"
