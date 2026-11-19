#!/bin/sh
# Native SIMH physical MM snapshots at exact pre-reclaim KINIT handoff.
# Two source-matched boot images x two hardware core sizes (48K/64K).
# Do not claim an uninterrupted all-time allocation peak from samples.
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
work=$(mktemp -d "$TMPDIR/daimos-v1669-mm-physical.XXXXXX")
keep=${KEEP_TEST:-0}
cleanup()
{
    if [ "$keep" = 1 ]; then
        echo "v1669 physical MM evidence: $work"
    else
        rm -rf "$work"
    fi
}
trap cleanup EXIT HUP INT TERM

for variant in general strict; do
    case "$variant" in
        general)
            boot=${V1669_GENERAL_BUILD:-$work/general-build}
            swapless=0
            ;;
        strict)
            boot=${V1669_STRICT_BUILD:-$work/strict-build}
            swapless=1
            ;;
    esac
    if [ "$variant" = general ] && [ -z "${V1669_GENERAL_BUILD:-}" ] || \
        [ "$variant" = strict ] && [ -z "${V1669_STRICT_BUILD:-}" ]; then
        make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
            BUILD="$boot" PDP10_PREFIX="$PDP10_PREFIX" \
            ROOT=tape BOOT=dtc BOOT_PROFILE=lowmem COMPILER=gcc \
            BOOT_CORE_WORDS=0200000 SIMH_CPU_KWORDS=64 \
            TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
            DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_PBM_V1667=0 \
            DAIMOS_SWAPLESS_ONLY_V1668="$swapless" \
            > "$work/$variant-build.log" 2>&1 || {
            tail -80 "$work/$variant-build.log" >&2
            keep=1; exit 1
        }
    fi
    test -s "$boot/boot.ini"
    test -s "$boot/kinit.map"
    test -s "$boot/kcore.map"
    grep -q '^proc_pure_mres_package_v1612[[:space:]]' "$boot/kinit.map"
    if [ "$variant" = strict ]; then
        if grep -q '^proc_swap_mres_package_v481[[:space:]]' \
            "$boot/kinit.map"; then
            echo 'FAIL v1669: strict image includes disk-swap MRES' >&2
            exit 1
        fi
    else
        grep -q '^proc_swap_mres_package_v481[[:space:]]' \
            "$boot/kinit.map"
    fi
    for n in 0 1 2; do
        test -s "$boot/media/dtc$n.tap"
    done
    late=$(awk '$1 == "kinit_late_start" {print $2; exit}' \
        "$boot/kinit.map")
    test -n "$late"
    symbols='mm_core_words mm_extent_capacity mm_arena_count mm_extent_count mm_arenas mm_extents sys_resident_words_immediate'
    for name in $symbols; do
        address=$(awk -v name="$name" '$1 == name { print $2; exit }' \
            "$boot/kcore.map")
        test -n "$address" || { echo "FAIL v1669: no $name" >&2; exit 1; }
        eval "sym_$name=$address"
    done
    for core in 48 64; do
        # Same KINIT, KCORE, root media and source flags are used at
        # both physical core sizes. Detach all DSK/DRM AUXSTORE media.
        awk -v core="$core" '
            /^attach -q (dsk[0-9]+|dr[0-9]+) / {next}
            /^set cpu [0-9]+k$/ {print "set cpu " core "k"; next}
            {print}
        ' "$boot/boot.ini" > "$work/$variant-$core-noaux.ini"
        grep -qx "set cpu ${core}k" "$work/$variant-$core-noaux.ini"
        if grep -Eq '^attach -q (dsk[0-9]+|dr[0-9]+) ' \
            "$work/$variant-$core-noaux.ini"; then
            echo 'FAIL v1669: unexpected physical AUXSTORE attached' >&2
            exit 1
        fi
        port=$((33000 + ($$ % 5000) + core + swapless * 100))
        sh "$kit/tests/lib/daimos-simh-headless.sh" \
            "$work/$variant-$core-noaux.ini" \
            "$work/$variant-$core-headless.ini" \
            "$port" "$((port + 14000))"
        # SIMH breakpoint is at actual KINIT_LATE entry. No guest-side
        # allocator instrumentation or resident state is linked.
        end=$((0$sym_mm_extents + 2 * 40 - 1))
        arena_end=$((0$sym_mm_arenas + 2))
        awk -v entry="$late" \
            -v core_addr="$sym_mm_core_words" \
            -v capacity_addr="$sym_mm_extent_capacity" \
            -v arena_count_addr="$sym_mm_arena_count" \
            -v extent_count_addr="$sym_mm_extent_count" \
            -v arena_base="$sym_mm_arenas" \
            -v arena_end="$(printf '%o' "$arena_end")" \
            -v extent_base="$sym_mm_extents" \
            -v extent_end="$(printf '%o' "$end")" \
            -v resident_addr="$sym_sys_resident_words_immediate" '
            /^go 020$/ {
                print "break " entry
                print
                print "examine " core_addr
                print "examine " capacity_addr
                print "examine " arena_count_addr
                print "examine " extent_count_addr
                print "examine " resident_addr
                print "examine " arena_base "-" arena_end
                print "examine " extent_base "-" extent_end
                print "exit"
                next
            }
            /^exit$/ {next}
            {print}
        ' "$work/$variant-$core-headless.ini" > \
            "$work/$variant-$core-probe.ini"
        set +e
        (
            cd "$boot"
            TERM=dumb timeout -k 3s "${V1669_TIMEOUT:-75}" \
                stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" \
                "$work/$variant-$core-probe.ini"
        ) > "$work/$variant-$core-console.log" 2>&1
        rc=$?
        set -e
        tr -d '\r' < "$work/$variant-$core-console.log" > \
            "$work/$variant-$core-console.clean"
        if [ "$rc" -ne 0 ]; then
            tail -75 "$work/$variant-$core-console.clean" >&2
            echo "FAIL v1669: $variant $core KINIT checkpoint missing" >&2
            keep=1; exit 1
        fi
        python3 "$here/measure-v1669.py" \
            "$boot/kinit.map" "$boot/kcore.map" \
            "$work/$variant-$core-console.clean" "$core" \
            "$work/$variant-$core-measured.json" || {
            tail -75 "$work/$variant-$core-console.clean" >&2
            keep=1; exit 1
        }
    done
done

python3 "$here/compare-v1669.py" \
    "$work/general-48-measured.json" \
    "$work/strict-48-measured.json" \
    "$work/general-64-measured.json" \
    "$work/strict-64-measured.json" \
    > "$work/compare-v1669.log" || {
    cat "$work/compare-v1669.log" >&2
    keep=1; exit 1
}
cat "$work/compare-v1669.log"

# Independent unsafe measurement mutations: an impossible packed
# MM arena, a missing physical MM count, and forged free accounting.
# All three must be rejected by the same original map-backed oracle.
python3 - "$work" "${V1669_GENERAL_BUILD:-$work/general-build}" <<'PY'
import json
import re
import sys
from pathlib import Path

work=Path(sys.argv[1])
source=Path(sys.argv[2])
kernel=(source/'kcore.map').read_text(encoding='ascii')


def addr(name):
    found=re.findall('^'+name+r'\s+([0-7]+)\s*$',kernel,re.M)
    if len(found)!=1:
        raise SystemExit('v1669 mutation map symbol drift '+name)
    return format(int(found[0],8),'o')


log=(work/'general-48-console.clean').read_text(encoding='ascii')
arena=r'^'+addr('mm_arenas')+r':\s+[0-7]{12}$'
if len(re.findall(arena,log,re.M))!=1:
    raise SystemExit('v1669 physical arena mutation anchor drift')
(work/'unsafe-arena.log').write_text(
    re.sub(arena,addr('mm_arenas')+':\t777777777777',log,count=1,
           flags=re.M),encoding='ascii')
count=r'^'+addr('mm_extent_count')+r':\s+[0-7]{12}\n'
if len(re.findall(count,log,re.M))!=1:
    raise SystemExit('v1669 physical MM count mutation anchor drift')
(work/'unsafe-missing-count.log').write_text(
    re.sub(count,'',log,count=1,flags=re.M),encoding='ascii')
data=json.loads((work/'strict-48-measured.json').read_text(encoding='ascii'))
data['free_mm_words']+=1
(work/'unsafe-free.json').write_text(json.dumps(data),encoding='ascii')
PY

general=${V1669_GENERAL_BUILD:-$work/general-build}
for mutant in unsafe-arena unsafe-missing-count; do
    if python3 "$here/measure-v1669.py" \
        "$general/kinit.map" "$general/kcore.map" \
        "$work/$mutant.log" 48 "$work/$mutant.json" \
        > "$work/$mutant-refusal.log" 2>&1; then
        echo "FAIL v1669: $mutant measurement mutation survived" >&2
        keep=1; exit 1
    fi
    grep -q '^FAIL v1669 physical MM proof:' \
        "$work/$mutant-refusal.log" || {
        cat "$work/$mutant-refusal.log" >&2; keep=1; exit 1;
    }
    echo "v1669: $mutant physical measurement mutation rejected"
done
if python3 "$here/compare-v1669.py" \
    "$work/general-48-measured.json" "$work/unsafe-free.json" \
    "$work/general-64-measured.json" "$work/strict-64-measured.json" \
    > "$work/unsafe-free-refusal.log" 2>&1; then
    echo 'FAIL v1669: forged physical free total survived' >&2
    keep=1; exit 1
fi
grep -q '^FAIL v1669 source-matched physical MM:' \
    "$work/unsafe-free-refusal.log" || {
    cat "$work/unsafe-free-refusal.log" >&2; keep=1; exit 1;
}
echo 'v1669: forged physical MM free total rejected'
echo 'PASS v1669: four source-matched physical KINIT MM checkpoints'
