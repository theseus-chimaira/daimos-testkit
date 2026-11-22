#!/bin/sh
# Source-matched physical PDP-6 48K RAW PURE reclaim and restoration.
# Test-only PID1 and minimal child replace INIT/MOUNTALL on disposable TSFS
# media; production INIT, KCORE, PURE and Type-551 drivers are unchanged.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
case "${V1673_ONLY_CORE:-48}" in
    48) ;;
    *) echo 'FAIL v1673: physical reclaim profile supports only 48K' >&2
       exit 2 ;;
esac
case "${V1673_ONLY_VARIANT:-both}" in
    general|strict|both) ;;
    *) echo 'FAIL v1673: unknown image profile' >&2; exit 2 ;;
esac
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
# An independent later test may select a caller-owned evidence directory;
# the default v1673 acceptance still uses its isolated mktemp directory.
work=${V1673_WORK_DIR:-}
if [ -n "$work" ]; then
    test -d "$work" || { echo 'FAIL v1673: no evidence directory' >&2; exit 2; }
else
    work=$(mktemp -d "$TMPDIR/daimos-v1673-runtime-physical.XXXXXX")
fi
keep=${KEEP_TEST:-0}
cleanup()
{
    if [ "$keep" = 1 ]; then
        echo "v1673 native pressure evidence: $work"
    else
        rm -rf "$work"
    fi
}
trap cleanup EXIT HUP INT TERM
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/pty-run" "$kit/tools/pty-run-v1.c"

fixture=${V1673_FIXTURE_BUILD:-$work/fixture}
if [ -z "${V1673_FIXTURE_BUILD:-}" ]; then
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
    guest_c=${V1673_GUEST_C:-$here/proc-pressure-v1673.c}
    guest_child=${V1673_CHILD_ASM:-$here/sleep-child-v1673.s}
    "$cc" -std=c89 -Os $incs -S "$guest_c" \
        -o "$fixture/pressure.s"
    "$das" -F -C -O "$fixture/pressure.dobj" "$fixture/pressure.s"
    "$das" -F -C -O "$fixture/checkpoint.dobj" \
        "$here/checkpoint-v1673.s"
    "$das" -F -C -O "$fixture/sleep-child.dobj" \
        "$guest_child"
    "$link" -b 020 --pure -o "$fixture/v1673-test-sleep.dxr" \
        -M "$fixture/v1673-test-sleep.map" "$fixture/sleep-child.dobj"
    libgcc=$($cc -print-libgcc-file-name)
    "$link" -b 020 -o "$fixture/v1673-test-init.dxr" \
        -M "$fixture/v1673-test-init.map" \
        "$fixture/crt0.dobj" "$fixture/syscall.dobj" \
        "$fixture/u.dobj" "$fixture/pressure.dobj" \
        "$fixture/checkpoint.dobj" "$libgcc"
fi
test -s "$fixture/v1673-test-init.dxr"
test -s "$fixture/v1673-test-init.map"
test -s "$fixture/v1673-test-sleep.dxr"
for name in v1673_before v1673_pressure v1673_reaped; do
    grep -q "^$name[[:space:]]" "$fixture/v1673-test-init.map"
done

for variant in general strict; do
    if [ "${V1673_ONLY_VARIANT:-both}" != both ] && \
        [ "$variant" != "$V1673_ONLY_VARIANT" ]; then
        continue
    fi
    case "$variant" in
        general)
            build=${V1673_GENERAL_BUILD:-$work/general-build}
            strict=0
            ;;
        strict)
            build=${V1673_STRICT_BUILD:-$work/strict-build}
            strict=1
            ;;
    esac
    if [ "$variant" = general ] && [ -z "${V1673_GENERAL_BUILD:-}" ] || \
        [ "$variant" = strict ] && [ -z "${V1673_STRICT_BUILD:-}" ]; then
        make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
            BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" \
            ROOT=tape BOOT=dtc BOOT_PROFILE=lowmem COMPILER=gcc \
            BOOT_CORE_WORDS=0200000 SIMH_CPU_KWORDS=64 \
            TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
            DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_PBM_V1667=0 \
            DAIMOS_SWAPLESS_ONLY_V1668="$strict" \
            SYSTEM_INIT_DXR="$fixture/v1673-test-init.dxr" \
            SYSTEM_MOUNTALL_DXR="$fixture/v1673-test-sleep.dxr" \
            > "$work/$variant-build.log" 2>&1 || {
            tail -85 "$work/$variant-build.log" >&2
            keep=1; exit 1
        }
    fi
    for f in boot.ini kcore.map kinit.map kinit.dxr tsfs-root.manifest; do
        test -s "$build/$f"
    done
    grep -Fxq "F /SYSTEM/INIT $fixture/v1673-test-init.dxr 0555 0 0" \
        "$build/tsfs-root.manifest" || {
        echo 'FAIL v1673: TSFS root does not contain exact test PID1' >&2
        exit 1
    }
    grep -Fxq "F /SYSTEM/EXEC/MOUNTALL $fixture/v1673-test-sleep.dxr 0555 0 0" \
        "$build/tsfs-root.manifest" || {
        echo 'FAIL v1673: TSFS root does not contain exact tiny child' >&2
        exit 1
    }
    grep -q '^proc_pure_mres_package_v1612[[:space:]]' "$build/kinit.map"
    if [ "$strict" = 0 ]; then
        grep -q '^proc_swap_mres_package_v481[[:space:]]' "$build/kinit.map"
    elif grep -q '^proc_swap_mres_package_v481[[:space:]]' \
        "$build/kinit.map"; then
        echo 'FAIL v1673: strict TSFS still links DISK SWAP MRES' >&2
        exit 1
    fi
    # The 9-child BRK/pressure geometry and one spare RUN slot are
    # deliberately source-backed for 48K. Do not accidentally treat
    # a 64K, no-reclaim test as successful reclaim acceptance.
    for core in 48; do
        if [ -n "${V1673_ONLY_CORE:-}" ] && \
            [ "$core" != "$V1673_ONLY_CORE" ]; then
            continue
        fi
        media="$work/$variant-$core-media"
        mkdir -p "$media"
        for n in 0 1 2 3; do
            source=$(awk -v dev="dtc$n" \
                '$1=="attach" && $3==dev {print $4;exit}' \
                "$build/boot.ini")
            if [ -z "$source" ] || [ ! -s "$source" ]; then
                echo "FAIL v1673: missing source DTC$n" >&2
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
            echo 'FAIL v1673: auxiliary swap media attached' >&2
            exit 1
        fi
        # User checkpoint virtual PCs overlap fixed KCORE instruction PCs.
        # Never set a raw SIMH breakpoint on a user fixture symbol.
        # PID1 holds on CTY while the host interrupts SIMH and examines
        # original physical MM fields at each phase A/B/C.
        cty_driver=${V1673_CTY_DRIVER:-$here/host-cty-v1673.py}
        if ! python3 "$cty_driver" \
            "$work/pty-run" "$PDP10_PREFIX/bin/pdp6" \
            "$work/$variant-$core-noaux.ini" "$build/kcore.map" \
            "$work/$variant-$core-console.log" \
            "${V1673_TIMEOUT:-900}" "$build"; then
            tr -d '\r' < "$work/$variant-$core-console.log" > \
                "$work/$variant-$core-console.clean"
            tail -75 "$work/$variant-$core-console.clean" >&2
            echo "FAIL v1673: incomplete $variant $core CTY runtime test" >&2
            keep=1; exit 1
        fi
        measure=${V1673_MEASURE:-$here/measure-v1673.py}
        python3 "$measure" \
            "$fixture/v1673-test-init.map" "$build/kcore.map" \
            "$work/$variant-$core-console.clean" "$core" \
            "$work/$variant-$core-report.json" || {
            tail -75 "$work/$variant-$core-console.clean" >&2
            keep=1; exit 1
        }
    done
done
if [ "${V1673_ONLY_VARIANT:-both}" != both ]; then
    echo 'PASS v1673: selected physical native RUN/EXIT/WAIT scenario'
    exit 0
fi
python3 "$here/compare-v1673.py" \
    "$work/general-48-report.json" "$work/strict-48-report.json" \
    > "$work/compare.log" || {
    cat "$work/compare.log" >&2;keep=1;exit 1
}
cat "$work/compare.log"
sh "$here/run-negative-v1673.sh" \
    "$work/strict-48-console.clean" \
    "$fixture/v1673-test-init.map" \
    "${V1673_STRICT_BUILD:-$work/strict-build}/kcore.map" \
    "$work/strict-48-report.json"
echo 'PASS v1673: general and strict 48K RAW PURE reclaim/restore/WAIT'
