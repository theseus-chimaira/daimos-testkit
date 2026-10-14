#!/bin/sh
# 3 independent hardware profiles; each media tree is built separately.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
DAS_REPO=${DAS_REPO:-$HOME/git/das}
KCC_REPO=${KCC_REPO:-$HOME/git/kcc}
PDP6_SIMH=${PDP6_SIMH:-pdp6}
export TMPDIR
root="$TMPDIR/packed-boot-matrix-v089"
mkdir -p "$root"
script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# Select profiles for a repeatable, isolated diagnostic rerun.
PACKED_BOOT_PROFILES=${PACKED_BOOT_PROFILES:-'tsfs d6fs full'}
PACKED_RUNTIME_V088=${PACKED_RUNTIME_V088:-1}
for profile in $PACKED_BOOT_PROFILES; do
    out="$root/$profile"
    # A test run owns this versioned tree: never boot stale writable media.
    rm -rf "$out"
    mkdir -p "$out"
    case "$profile" in
        tsfs) boot=dtc; fs=tape; mem=32; build=lowmem; members=1; simh_timeout=170 ;;
        d6fs) boot=dsk; fs=disk; mem=32; build=lowmem; members=1; simh_timeout=100 ;;
        full) boot=dsk; fs=auto; mem=256; build=full; members=4; simh_timeout=110 ;;
    esac
    printf 'PROFILE %s: %sK PDP-6, BOOT=%s ROOT=%s\n' "$profile" "$mem" "$boot" "$fs"
    make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
        COMPILER=gcc PDP10_PREFIX="$PDP10_PREFIX" \
        PACKED_RUNTIME_V088="$PACKED_RUNTIME_V088" \
        D6FS_ROOT_MEMBERS="$members" TSFS_ROOT_MEMBERS=1 \
        MINIMAL_HW_V089=$([ "$profile" = full ] && echo 0 || echo 1) \
        BUILD="$out/image" BUILD_ROOT="$out/build" \
        DAS_REPO="$DAS_REPO" KCC_REPO="$KCC_REPO" \
        BOOT_PROFILE="$build" BOOT="$boot" ROOT="$fs" \
        SIMH_DPY_MODE=HEADLESS SIMH_CPU_KWORDS="$mem"
    ini="$out/image/boot.ini"
    if test "$profile" = full; then
        grep -q '^set cpu 256k$' "$ini"
        for device in pclk cr cp ptr ptp lpt dsk dp dr dr0 dr1 dr2 dr3 dct dtc dtc0 dtc1 dtc2 dtc3 mtc mtc0 mtc1 dcs ge slave dpy wcnsls ocnsls; do
            grep -q "^set $device enabled$" "$ini" || {
                echo "FAIL full profile has no enabled $device" >&2; exit 1;
            }
        done
        for device in ptr ptp cp lpt dsk0 dsk1 dsk2 dsk3 dr0 dr1 dr2 dr3 dtc0 dtc1 dtc2 dtc3 mtc0 mtc1 dcs0 ge0; do
            grep -Eq "^attach .* $device " "$ini" || {
                echo "FAIL full profile has no attachment for $device" >&2; exit 1;
            }
        done
    fi
    if test "$profile" != full; then
        python3 "$script_dir/minimal-config-v089.py" "$profile" "$ini" "$out/minimal.ini"
        ini="$out/minimal.ini"
    fi
    # SIMH can remain active after reaching INIT; timeout is expected.
    timeout "$simh_timeout" "$PDP6_SIMH" "$ini" > "$out/simh.log" 2>&1 || {
        rc=$?; if test "$rc" != 124; then tail -40 "$out/simh.log"; exit "$rc"; fi
    }
    if ! grep -q 'INIT V1' "$out/simh.log"; then
        tail -35 "$out/simh.log"
        echo "FAIL $profile did not reach INIT V1" >&2
        exit 1
    fi
    if grep -E -q 'HALT instruction|[?]RT' "$out/simh.log"; then
        tail -35 "$out/simh.log"
        echo "FAIL $profile halted before clean user operation" >&2
        exit 1
    fi
    echo "PASS $profile INIT V1"
done
