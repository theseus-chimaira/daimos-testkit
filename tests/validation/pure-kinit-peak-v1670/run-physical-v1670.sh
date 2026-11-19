#!/bin/sh
# Two source-matched PDP-6 KINIT images, two physical core sizes.
# Simulator hooks record existing MM mutation-entry states until the
# first VM user handoff; no permanent or disposable guest code changes.
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
work=$(mktemp -d "$TMPDIR/daimos-v1670-physical-peak.XXXXXX")
keep=${KEEP_TEST:-0}
cleanup()
{
    if [ "$keep" = 1 ]; then
        echo "v1670 physical peak evidence: $work"
    else
        rm -rf "$work"
    fi
}
trap cleanup EXIT HUP INT TERM

for variant in general strict; do
    case "$variant" in
        general)
            boot=${V1670_GENERAL_BUILD:-$work/general-build}
            swapless=0
            ;;
        strict)
            boot=${V1670_STRICT_BUILD:-$work/strict-build}
            swapless=1
            ;;
    esac
    if [ "$variant" = general ] && [ -z "${V1670_GENERAL_BUILD:-}" ] || \
        [ "$variant" = strict ] && [ -z "${V1670_STRICT_BUILD:-}" ]; then
        make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
            BUILD="$boot" PDP10_PREFIX="$PDP10_PREFIX" \
            ROOT=tape BOOT=dtc BOOT_PROFILE=lowmem COMPILER=gcc \
            BOOT_CORE_WORDS=0200000 SIMH_CPU_KWORDS=64 \
            TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
            DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_PBM_V1667=0 \
            DAIMOS_SWAPLESS_ONLY_V1668="$swapless" \
            > "$work/$variant-build.log" 2>&1 || {
            tail -70 "$work/$variant-build.log" >&2; keep=1; exit 1;
        }
    fi
    test -s "$boot/kinit.dxr"
    test -s "$boot/boot.ini"
    grep -q '^proc_pure_mres_package_v1612[[:space:]]' "$boot/kinit.map"
    if [ "$variant" = general ]; then
        grep -q '^proc_swap_mres_package_v481[[:space:]]' "$boot/kinit.map"
    elif grep -q '^proc_swap_mres_package_v481[[:space:]]' "$boot/kinit.map"; then
        echo 'FAIL v1670: strict image still contains disk-swap MRES' >&2
        exit 1
    fi
    for n in 0 1 2 3; do
        source=$(awk -v device="dtc$n" \
            '$1 == "attach" && $3 == device {print $4; exit}' \
            "$boot/boot.ini")
        test -n "$source" && test -s "$source" || {
            echo "FAIL v1670: source DTC$n image missing" >&2; exit 1;
        }
    done

    for core in 48 64; do
        # Copy every physically attached DECtape before boot. A guest
        # cannot modify the media used in the later paired run.
        mkdir -p "$work/$variant-$core-media"
        for n in 0 1 2 3; do
            source=$(awk -v device="dtc$n" \
                '$1 == "attach" && $3 == device {print $4; exit}' \
                "$boot/boot.ini")
            cp "$source" \
                "$work/$variant-$core-media/dtc$n.tap"
        done
        awk -v core="$core" -v media="$work/$variant-$core-media" '
            /^attach -q (dsk[0-9]+|dr[0-9]+) / {next}
            /^set cpu [0-9]+k$/ {print "set cpu " core "k"; next}
            /^attach -q dtc[0-3] / {
                print "attach -q " $3 " " media "/" $3 ".tap"
                next
            }
            {print}
        ' "$boot/boot.ini" > "$work/$variant-$core-noaux.ini"
        grep -qx "set cpu ${core}k" "$work/$variant-$core-noaux.ini"
        if grep -Eq '^attach -q (dsk[0-9]+|dr[0-9]+) ' \
            "$work/$variant-$core-noaux.ini"; then
            echo 'FAIL v1670: unexpected physical AUX backing' >&2
            exit 1
        fi
        for n in 0 1 2 3; do
            grep -Fqx "attach -q dtc$n $work/$variant-$core-media/dtc$n.tap" \
                "$work/$variant-$core-noaux.ini" || {
                echo "FAIL v1670: missing isolated DTC$n" >&2; exit 1;
            }
        done
        port=$((33400 + ($$ % 5000) + core + swapless * 100))
        sh "$kit/tests/lib/daimos-simh-headless.sh" \
            "$work/$variant-$core-noaux.ini" \
            "$work/$variant-$core-headless.ini" \
            "$port" "$((port + 14000))"
        python3 "$here/make-probe-v1670.py" \
            "$boot/kinit.map" "$boot/kcore.map" \
            "$work/$variant-$core-headless.ini" \
            "$work/$variant-$core-probe.ini" \
            > "$work/$variant-$core-build-probe.log"
        set +e
        (
            cd "$boot"
            TERM=dumb timeout -k 3s "${V1670_TIMEOUT:-95}" \
                stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" \
                "$work/$variant-$core-probe.ini"
        ) > "$work/$variant-$core-console.log" 2>&1
        rc=$?
        set -e
        tr -d '\r' < "$work/$variant-$core-console.log" > \
            "$work/$variant-$core-console.clean"
        if [ "$rc" -ne 0 ] || \
            [ "$(wc -c < "$work/$variant-$core-console.clean")" -gt 8000000 ]; then
            tail -75 "$work/$variant-$core-console.clean" >&2
            echo "FAIL v1670: incomplete/beyond-limit SIMH $variant $core" >&2
            keep=1; exit 1
        fi
        python3 "$here/trace-v1670.py" \
            "$boot/kinit.map" "$boot/kcore.map" \
            "$work/$variant-$core-console.clean" "$core" \
            "$work/$variant-$core-report.json" || {
            tail -75 "$work/$variant-$core-console.clean" >&2
            keep=1; exit 1;
        }
    done
done

python3 "$here/compare-v1670.py" \
    "$work/general-48-report.json" "$work/strict-48-report.json" \
    "$work/general-64-report.json" "$work/strict-64-report.json" \
    > "$work/compare.log" || {
    cat "$work/compare.log" >&2; keep=1; exit 1;
}
cat "$work/compare.log"

# Deliberately corrupt real event evidence and a summarized high-water
# figure. Test the same physical-state proof, not just text greps.
python3 - "$work" "${V1670_STRICT_BUILD:-$work/strict-build}" <<'PY'
import json
import re
import sys
from pathlib import Path

work=Path(sys.argv[1])
build=Path(sys.argv[2])
maps=(build/'kcore.map').read_text(encoding='ascii')


def symbol(name):
    found=re.findall('^'+name+r'\s+([0-7]+)\s*$',maps,re.M)
    if len(found)!=1:
        raise SystemExit('v1670 corruption map anchor drift '+name)
    return int(found[0],8)


text=(work/'strict-48-console.clean').read_text(encoding='ascii')
start='Breakpoint, PC: %06o' % symbol('mm_extent_insert')
# The source trace begins at MRES_INIT. Mutate an arena in the
# interval following that marker, not in the pre-init sample.
init=(build/'kinit.map').read_text(encoding='ascii')
init_addr=re.findall(r'^mres_init\s+([0-7]+)\s*$',init,re.M)
if len(init_addr)!=1:
    raise SystemExit('v1670 missing MRES_INIT marker')
prefix='Breakpoint, PC: %06o' % int(init_addr[0],8)
if text.count(prefix)!=1 or start not in text:
    raise SystemExit('v1670 trace stage markers drift')
before,after=text.split(prefix,1)
arena=r'^%o:\s+[0-7]{12}$' % symbol('mm_arenas')
if len(re.findall(arena,after,re.M))<1:
    raise SystemExit('v1670 MM arena mutation anchor drift')
after=re.sub(arena,('%o:\t777777777777' % symbol('mm_arenas')),
             after,count=1,flags=re.M)
(work/'unsafe-arena.log').write_text(before+prefix+after,encoding='ascii')
last='Breakpoint, PC: %06o' % symbol('vm_enter_initial_user')
if text.count(last)!=1:
    raise SystemExit('v1670 terminal marker drift')
(work/'unsafe-no-terminal.log').write_text(
    text.split(last,1)[0],encoding='ascii')
report=json.loads((work/'strict-48-report.json').read_text(encoding='ascii'))
report['max_sampled_nonfree']+=1
(work/'unsafe-peak.json').write_text(json.dumps(report),encoding='ascii')
PY
strict=${V1670_STRICT_BUILD:-$work/strict-build}
for mutant in unsafe-arena unsafe-no-terminal; do
    if python3 "$here/trace-v1670.py" \
        "$strict/kinit.map" "$strict/kcore.map" "$work/$mutant.log" 48 \
        "$work/$mutant.json" > "$work/$mutant-refusal.log" 2>&1; then
        echo "FAIL v1670: $mutant physical evidence mutation survived" >&2
        keep=1; exit 1
    fi
    grep -q '^FAIL v1670 physical event trace:' \
        "$work/$mutant-refusal.log" || {
        cat "$work/$mutant-refusal.log" >&2; keep=1; exit 1;
    }
    echo "v1670: executed $mutant trace corruption rejected"
done
if python3 "$here/compare-v1670.py" \
    "$work/general-48-report.json" "$work/unsafe-peak.json" \
    "$work/general-64-report.json" "$work/strict-64-report.json" \
    > "$work/unsafe-peak-refusal.log" 2>&1; then
    echo 'FAIL v1670: forged sampled high-water accepted' >&2
    keep=1; exit 1
fi
grep -q '^FAIL v1670 paired physical peak:' \
    "$work/unsafe-peak-refusal.log" || {
    cat "$work/unsafe-peak-refusal.log" >&2; keep=1; exit 1;
}
echo 'v1670: forged high-water report rejected'
echo 'PASS v1670: four source-matched physical allocator event traces'
