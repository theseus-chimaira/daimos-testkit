#!/bin/sh
# Source-matched physical PDP-6 48K/64K PURE process memory pressure.
# Test-only PID1 and minimal child replace INIT/MOUNTALL on disposable TSFS
# media; production INIT, KCORE, PURE and Type-551 drivers are unchanged.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-v1672-runtime-physical.XXXXXX")
keep=${KEEP_TEST:-0}
cleanup()
{
    if [ "$keep" = 1 ]; then
        echo "v1672 native pressure evidence: $work"
    else
        rm -rf "$work"
    fi
}
trap cleanup EXIT HUP INT TERM
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/pty-run" "$kit/tools/pty-run-v1.c"

fixture=${V1672_FIXTURE_BUILD:-$work/fixture}
if [ -z "${V1672_FIXTURE_BUILD:-}" ]; then
    mkdir -p "$fixture"
    cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
    das="$PDP10_PREFIX/bin/das"
    link="$PDP10_PREFIX/bin/dlink"
    incs="-I$DAIMOS_REPO/userland/libc"
    for dir in proc core boot fs drivers modules storage; do
        incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
    done
    incs="$incs -I$PDP10_PREFIX/include"
    for part in crt0 syscall; do
        "$das" -F -C -O "$fixture/$part.dobj" \
            "$DAIMOS_REPO/userland/libc/$part.s"
    done
    "$cc" -std=c89 -Os $incs -S \
        "$DAIMOS_REPO/userland/libc/u.c" -o "$fixture/u.s"
    "$das" -F -C -O "$fixture/u.dobj" "$fixture/u.s"
    "$cc" -std=c89 -Os $incs -S "$here/proc-pressure-v1672.c" \
        -o "$fixture/pressure.s"
    "$das" -F -C -O "$fixture/pressure.dobj" "$fixture/pressure.s"
    "$das" -F -C -O "$fixture/checkpoint.dobj" \
        "$here/checkpoint-v1672.s"
    "$das" -F -C -O "$fixture/sleep-child.dobj" \
        "$here/sleep-child-v1672.s"
    "$link" -b 020 -o "$fixture/v1672-test-sleep.dxr" \
        -M "$fixture/v1672-test-sleep.map" "$fixture/sleep-child.dobj"
    libgcc=$($cc -print-libgcc-file-name)
    "$link" -b 020 -o "$fixture/v1672-test-init.dxr" \
        -M "$fixture/v1672-test-init.map" \
        "$fixture/crt0.dobj" "$fixture/syscall.dobj" \
        "$fixture/u.dobj" "$fixture/pressure.dobj" \
        "$fixture/checkpoint.dobj" "$libgcc"
fi
test -s "$fixture/v1672-test-init.dxr"
test -s "$fixture/v1672-test-init.map"
test -s "$fixture/v1672-test-sleep.dxr"
for name in v1672_before v1672_pressure v1672_reaped; do
    grep -q "^$name[[:space:]]" "$fixture/v1672-test-init.map"
done

for variant in general strict; do
    if [ -n "${V1672_ONLY_VARIANT:-}" ] && \
        [ "$variant" != "$V1672_ONLY_VARIANT" ]; then
        continue
    fi
    case "$variant" in
        general)
            build=${V1672_GENERAL_BUILD:-$work/general-build}
            strict=0
            ;;
        strict)
            build=${V1672_STRICT_BUILD:-$work/strict-build}
            strict=1
            ;;
    esac
    if [ "$variant" = general ] && [ -z "${V1672_GENERAL_BUILD:-}" ] || \
        [ "$variant" = strict ] && [ -z "${V1672_STRICT_BUILD:-}" ]; then
        make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
            BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" \
            ROOT=tape BOOT=dtc BOOT_PROFILE=lowmem COMPILER=gcc \
            BOOT_CORE_WORDS=0200000 SIMH_CPU_KWORDS=64 \
            TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
            DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_PBM_V1667=0 \
            DAIMOS_SWAPLESS_ONLY_V1668="$strict" \
            SYSTEM_INIT_DXR="$fixture/v1672-test-init.dxr" \
            SYSTEM_MOUNTALL_DXR="$fixture/v1672-test-sleep.dxr" \
            > "$work/$variant-build.log" 2>&1 || {
            tail -85 "$work/$variant-build.log" >&2
            keep=1; exit 1
        }
    fi
    for f in boot.ini kcore.map kinit.map kinit.dxr tsfs-root.manifest; do
        test -s "$build/$f"
    done
    grep -Fxq "F /SYSTEM/INIT $fixture/v1672-test-init.dxr 0555 0 0" \
        "$build/tsfs-root.manifest" || {
        echo 'FAIL v1672: TSFS root does not contain exact test PID1' >&2
        exit 1
    }
    grep -Fxq "F /SYSTEM/EXEC/MOUNTALL $fixture/v1672-test-sleep.dxr 0555 0 0" \
        "$build/tsfs-root.manifest" || {
        echo 'FAIL v1672: TSFS root does not contain exact tiny child' >&2
        exit 1
    }
    grep -q '^proc_pure_mres_package_v1612[[:space:]]' "$build/kinit.map"
    if [ "$strict" = 0 ]; then
        grep -q '^proc_swap_mres_package_v481[[:space:]]' "$build/kinit.map"
    elif grep -q '^proc_swap_mres_package_v481[[:space:]]' \
        "$build/kinit.map"; then
        echo 'FAIL v1672: strict TSFS still links DISK SWAP MRES' >&2
        exit 1
    fi
    for core in 48 64; do
        if [ -n "${V1672_ONLY_CORE:-}" ] && \
            [ "$core" != "$V1672_ONLY_CORE" ]; then
            continue
        fi
        media="$work/$variant-$core-media"
        mkdir -p "$media"
        for n in 0 1 2 3; do
            source=$(awk -v dev="dtc$n" \
                '$1=="attach" && $3==dev {print $4;exit}' \
                "$build/boot.ini")
            if [ -z "$source" ] || [ ! -s "$source" ]; then
                echo "FAIL v1672: missing source DTC$n" >&2
                exit 1
            fi
            cp "$source" "$media/dtc$n.tap"
        done
        awk -v core="$core" -v media="$media" '
            /^attach -q (dsk[0-9]+|dr[0-9]+) / {next}
            /^set cpu [0-9]+k$/ {print "set cpu " core "k"; next}
            # SIMH must remain at its monitor after CTRL-E. Leaving
            # the trailing boot-script exit makes it say Goodbye.
            /^exit$/ {next}
            /^attach -q dtc[0-3] / {
                print "attach -q " $3 " " media "/" $3 ".tap"
                next
            }
            {print}
        ' "$build/boot.ini" > "$work/$variant-$core-noaux.ini"
        grep -qx "set cpu ${core}k" "$work/$variant-$core-noaux.ini"
        if grep -Eq '^attach -q (dsk[0-9]+|dr[0-9]+) ' \
            "$work/$variant-$core-noaux.ini"; then
            echo 'FAIL v1672: auxiliary swap media attached' >&2
            exit 1
        fi
        # User checkpoint virtual PCs overlap fixed KCORE instruction PCs.
        # Never set a raw SIMH breakpoint on a user fixture symbol.
        # PID1 holds on CTY while the host interrupts SIMH and examines
        # original physical MM fields at each phase A/B/C.
        if ! python3 "$here/host-cty-v1672.py" \
            "$work/pty-run" "$PDP10_PREFIX/bin/pdp6" \
            "$work/$variant-$core-noaux.ini" "$build/kcore.map" \
            "$work/$variant-$core-console.log" \
            "${V1672_TIMEOUT:-400}" "$build"; then
            tr -d '\r' < "$work/$variant-$core-console.log" > \
                "$work/$variant-$core-console.clean"
            tail -75 "$work/$variant-$core-console.clean" >&2
            echo "FAIL v1672: incomplete $variant $core CTY runtime test" >&2
            keep=1; exit 1
        fi
        python3 "$here/measure-v1672.py" \
            "$fixture/v1672-test-init.map" "$build/kcore.map" \
            "$work/$variant-$core-console.clean" "$core" \
            "$work/$variant-$core-report.json" || {
            tail -75 "$work/$variant-$core-console.clean" >&2
            keep=1; exit 1
        }
    done
done
if [ -n "${V1672_ONLY_VARIANT:-}" ] || \
    [ -n "${V1672_ONLY_CORE:-}" ]; then
    echo 'PASS v1672: selected physical native RUN/EXIT/WAIT scenario'
    exit 0
fi
python3 "$here/compare-v1672.py" \
    "$work/general-48-report.json" "$work/strict-48-report.json" \
    "$work/general-64-report.json" "$work/strict-64-report.json" \
    > "$work/compare.log" || {
    cat "$work/compare.log" >&2;keep=1;exit 1
}
cat "$work/compare.log"
echo 'PASS v1672: four native PDP-6 RUN/EXIT/WAIT MM lifecycles'
