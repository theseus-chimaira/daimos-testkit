#!/bin/sh
# Source-matched 48K/64K watermark-enabled KINIT images. The guest's
# native sentinel scanner and the physical 0400-word stack are checked
# independently at first user VM entry, with zero new production code.
set -eu
: "${DAIMOS_REPO:?DAIMOS source tree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-v1671-physical-stack.XXXXXX")
keep=${KEEP_TEST:-0}
cleanup()
{
    if [ "$keep" = 1 ]; then
        echo "v1671 physical stack evidence: $work"
    else
        rm -rf "$work"
    fi
}
trap cleanup EXIT HUP INT TERM

for variant in general strict; do
    case "$variant" in
        general)
            build=${V1671_GENERAL_BUILD:-$work/general-build}
            strict=0
            ;;
        strict)
            build=${V1671_STRICT_BUILD:-$work/strict-build}
            strict=1
            ;;
    esac
    if [ "$variant" = general ] && [ -z "${V1671_GENERAL_BUILD:-}" ] || \
        [ "$variant" = strict ] && [ -z "${V1671_STRICT_BUILD:-}" ]; then
        make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
            BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" \
            ROOT=tape BOOT=dtc BOOT_PROFILE=lowmem COMPILER=gcc \
            BOOT_CORE_WORDS=0200000 SIMH_CPU_KWORDS=64 \
            TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
            DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_PBM_V1667=0 \
            DAIMOS_SWAPLESS_ONLY_V1668="$strict" \
            KINIT_STACK_WATERMARK=1 KINIT_STACK_RESERVE_WORDS=0400 \
            > "$work/$variant-build.log" 2>&1 || {
            tail -70 "$work/$variant-build.log" >&2; keep=1; exit 1;
        }
    fi
    for f in kinit.map kcore.map boot.ini kinit.dxr; do
        test -s "$build/$f"
    done
    for name in kinit_stack_watermark_begin kinit_stack_watermark_measure \
        vm_enter_initial_user __kinit_image_end; do
        grep -q "^$name[[:space:]]" "$build/kinit.map"
    done
    grep -q '^kinit_stack_highwater[[:space:]]' "$build/kcore.map"
    grep -q '^proc_pure_mres_package_v1612[[:space:]]' "$build/kinit.map"
    if [ "$strict" = 1 ]; then
        if grep -q '^proc_swap_mres_package_v481[[:space:]]' \
            "$build/kinit.map"; then
            echo 'FAIL v1671: strict diagnostic linked DISK MRES' >&2
            exit 1
        fi
    else
        grep -q '^proc_swap_mres_package_v481[[:space:]]' "$build/kinit.map"
    fi

    begin=$(awk '$1=="kinit_stack_watermark_begin" {print $2;exit}' \
        "$build/kinit.map")
    terminal=$(awk '$1=="vm_enter_initial_user" {print $2;exit}' \
        "$build/kinit.map")
    top=$(awk '$1=="__kinit_image_end" {print $2;exit}' \
        "$build/kinit.map")
    highwater=$(awk '$1=="kinit_stack_highwater" {print $2;exit}' \
        "$build/kcore.map")
    resident=$(awk '$1=="sys_resident_words_immediate" {print $2;exit}' \
        "$build/kcore.map")
    stack_end=$(printf '%o' "$((0$top + 0400 - 1))")
    for core in 48 64; do
        mkdir -p "$work/$variant-$core-media"
        for n in 0 1 2 3; do
            source=$(awk -v dev="dtc$n" \
                '$1=="attach" && $3==dev {print $4;exit}' \
                "$build/boot.ini")
            if [ -z "$source" ] || [ ! -s "$source" ]; then
                echo "FAIL v1671: missing DTC$n source image" >&2
                exit 1
            fi
            cp "$source" "$work/$variant-$core-media/dtc$n.tap"
        done
        awk -v core="$core" -v media="$work/$variant-$core-media" '
            /^attach -q (dsk[0-9]+|dr[0-9]+) / {next}
            /^set cpu [0-9]+k$/ {print "set cpu " core "k";next}
            /^attach -q dtc[0-3] / {
                print "attach -q " $3 " " media "/" $3 ".tap"
                next
            }
            {print}
        ' "$build/boot.ini" > "$work/$variant-$core-noaux.ini"
        grep -qx "set cpu ${core}k" "$work/$variant-$core-noaux.ini"
        port=$((33700 + ($$ % 4700) + core + strict * 120))
        sh "$kit/tests/lib/daimos-simh-headless.sh" \
            "$work/$variant-$core-noaux.ini" \
            "$work/$variant-$core-headless.ini" \
            "$port" "$((port+14000))"
        awk -v begin="$begin" -v terminal="$terminal" \
            -v mark="$highwater" -v resident="$resident" \
            -v start="$top" -v end="$stack_end" '
            /^go 020$/ {
                print "break " begin ";go"
                print "break " terminal ";examine " mark \
                    ";examine " resident ";examine " start "-" end ";exit"
                print
                next
            }
            /^exit$/ {next}
            {print}
        ' "$work/$variant-$core-headless.ini" > \
            "$work/$variant-$core-probe.ini"
        set +e
        (
            cd "$build"
            TERM=dumb timeout -k 3s "${V1671_TIMEOUT:-95}" \
                stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" \
                "$work/$variant-$core-probe.ini"
        ) > "$work/$variant-$core-console.log" 2>&1
        rc=$?
        set -e
        tr -d '\r' < "$work/$variant-$core-console.log" > \
            "$work/$variant-$core-console.clean"
        if [ "$rc" -ne 0 ] || \
            [ "$(wc -c < "$work/$variant-$core-console.clean")" -gt 1000000 ]; then
            tail -55 "$work/$variant-$core-console.clean" >&2
            echo "FAIL v1671: SIMH diagnostic $variant $core did not exit" >&2
            keep=1;exit 1
        fi
        python3 "$here/measure-v1671.py" "$build/kinit.map" \
            "$build/kcore.map" "$work/$variant-$core-console.clean" \
            "$core" "$work/$variant-$core-report.json" || {
            tail -70 "$work/$variant-$core-console.clean" >&2
            keep=1;exit 1
        }
    done
done
python3 "$here/compare-v1671.py" \
    "$work/general-48-report.json" "$work/strict-48-report.json" \
    "$work/general-64-report.json" "$work/strict-64-report.json" \
    | tee "$work/compare.log"
sh "$here/run-negative-v1671.sh" "$work" \
    "${V1671_STRICT_BUILD:-$work/strict-build}"
echo 'PASS v1671: four genuine 48K/64K physical KINIT stack watermarks'
