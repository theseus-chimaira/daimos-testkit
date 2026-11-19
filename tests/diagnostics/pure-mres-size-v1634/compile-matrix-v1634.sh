#!/bin/sh
# Size-only compiler experiment for the original removable PURE MRES.
# No kernel source, guest media, linked KCORE or default compiler flags
# are modified; each candidate is linked in a unique scratch directory.
set -eu
: "${DAIMOS_REPO:?matching original DAIMOS checkout required}"
: "${PURE_MRES_BUILD_V1634:?original source-matched PURE-on build required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/pure-mres-size-v1634.XXXXXX")
trap 'echo "v1634 compiler experiment and evidence: $work"' EXIT HUP INT TERM
root="$DAIMOS_REPO/system/kernel"
bin="$PDP10_PREFIX/bin"
original="$PURE_MRES_BUILD_V1634"
for item in pure-rebase-v1611.dobj pure-expand-v1611.dobj \
            pure-image-v1611.dobj kcore.map pure-mres-v1612.dxr; do
    test -r "$original/$item"
done

export PURE_MRES_MATRIX_DIR_V1634="$work"
python3 - "$original/pure-mres-v1612.dxr" "$bin/dxrcheck" <<'PY'
import subprocess
import sys
import re
line = subprocess.check_output([sys.argv[2], '-d', sys.argv[1]],
                               text=True, encoding='ascii').splitlines()[0]
match = re.search(r'image=([0-7]+)', line)
assert match and int(match.group(1), 8) == 0o3336, \
    'baseline size changed; revalidate before comparing'
print('v1634 authenticated original PURE MRES: 003336 octal words')
PY

printf 'profile,image_octal,image_decimal,saved_decimal,folded_entries\n' \
    >"$work/matrix.csv"

for profile in Os O2 O1 OsNoInline OsOmitFrame OsNoCse \
    OsNoStrength OsNoBuiltin; do
    case "$profile" in
    Os) opt=-Os ;;
    O2) opt=-O2 ;;
    O1) opt=-O1 ;;
    OsNoInline) opt='-Os -fno-inline' ;;
    OsOmitFrame) opt='-Os -fomit-frame-pointer' ;;
    OsNoCse) opt='-Os -fno-cse-follow-jumps' ;;
    OsNoStrength) opt='-Os -fno-strength-reduce' ;;
    OsNoBuiltin) opt='-Os -fno-builtin' ;;
    esac
    dir="$work/$profile"
    mkdir -p "$dir"
    (
        cd "$root"
        for item in service drop prefix full; do
            case "$item" in
            service) src=proc/proc_pure_service_pdp6_v1612.c
                     name=proc_pure_service_v1612
                     extra='' ;;
            drop) src=proc/proc_pure_ram_v1381.c
                  name=proc_pure_drop_v1611
                  extra='-DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 -DDAIMOS_PURE_DROP_ONLY_V1611=1' ;;
            prefix) src=proc/proc_pure_restore_v1384.c
                    name=proc_pure_prefix_v1611
                    extra='-DDAIMOS_SWAPLESS_PREFIX_V1384=1' ;;
            full) src=proc/proc_pure_ram_restore_v1391.c
                  name=proc_pure_full_v1611
                  extra='-DDAIMOS_PURE_FULL_V1391=1' ;;
            esac
            # Compiler syntax from the real boot makefile; omit all
            # configuration changes except the requested -O profile.
            "$bin/pdp10-dec-none-gcc" -std=gnu99 $opt \
                -march=pdp6 -mcpu=pdp6 $extra \
                -I. -Iboot -Icore -Idrivers -Ifs -Iipc -Imm \
                -Imodules -Iproc -Istorage -I"$PDP10_PREFIX/include" \
                -S "$src" -o "$dir/$name.s" \
                >"$dir/$name.compile.log" 2>&1
            # -F is part of the real PDP-6 boot assembler flags.
            # Omitting it changes object length despite identical .s.
            "$bin/das" -F -C -O "$dir/$name.dobj" "$dir/$name.s" \
                >"$dir/$name.assemble.log" 2>&1
        done
    )
    for other in pure-rebase pure-expand pure-image; do
        cp "$original/$other-v1611.dobj" "$dir/$other-v1611.dobj"
    done
    set -- "$dir/proc_pure_service_v1612.dobj" \
        "$dir/proc_pure_drop_v1611.dobj" \
        "$dir/proc_pure_prefix_v1611.dobj" \
        "$dir/proc_pure_full_v1611.dobj" \
        "$dir/pure-rebase-v1611.dobj" \
        "$dir/pure-expand-v1611.dobj" \
        "$dir/pure-image-v1611.dobj"
    "$bin/p10fold" -m 20 -P "$dir/fold-v1634.txt" "$@" \
        >"$dir/p10fold.log" 2>&1
    "$bin/dlink" -b 0 -A "$original/kcore.map" \
        --fold-plan "$dir/fold-v1634.txt" \
        -o "$dir/pure-size-v1634.dxr" -M "$dir/pure-size-v1634.map" \
        -R "$dir/pure-size-v1634.dobj" \
        -N proc_pure_mres_package_v1612 \
        -X proc_pure_mres_reclaim_v1612 \
        -X proc_pure_mres_service_v1612 "$@" \
        >"$dir/dlink.log" 2>&1
    "$bin/dxrcheck" -d "$dir/pure-size-v1634.dxr" \
        >"$dir/dxrcheck.log"
    if [ "$profile" = Os ]; then
        # Matching the image length alone is insufficient: the source,
        # GCC backend, DAS -F pass, folding and relocation must all agree.
        if ! cmp -s "$original/pure-mres-v1612.dxr" \
            "$dir/pure-size-v1634.dxr"; then
            echo 'FAIL v1634: original -Os DXR bytes are not reproduced' >&2
            exit 1
        fi
        echo 'PASS v1634: original -Os DXR reproduced byte-for-byte'
    fi
    python3 - "$profile" "$dir/dxrcheck.log" "$dir/fold-v1634.txt" \
        "$work/matrix.csv" <<'PY'
from pathlib import Path
import re
import sys
profile, logfile, foldfile, csv = sys.argv[1:]
line = Path(logfile).read_text(encoding='ascii').splitlines()[0]
m = re.search(r'image=([0-7]+)', line)
assert m, 'missing linked package image size'
size = int(m.group(1), 8)
folds = sum(1 for s in Path(foldfile).read_text(encoding='ascii').splitlines()
            if s.startswith('FOLD\t'))
saved = 0o3336 - size
print('v1634 %s: MRES=%06o (%d) saved=%+d decimal folds=%d' %
      (profile, size, size, saved, folds))
with open(csv, 'a', encoding='ascii') as out:
    out.write('%s,%06o,%d,%+d,%d\n' % (profile, size, size, saved, folds))
PY
done
python3 - "$work/matrix.csv" <<'PY'
from pathlib import Path
import csv
import sys
records = list(csv.DictReader(Path(sys.argv[1]).open(encoding='ascii')))
baseline = [r for r in records if r['profile'] == 'Os']
assert len(baseline) == 1
assert int(baseline[0]['image_decimal']) == 1758, \
    'source-identical -Os assembler/linker size failed reproduction'
best = min(records, key=lambda r: int(r['image_decimal']))
print('v1634 best: %s, %s words (%s saved from baseline)' %
      (best['profile'], best['image_decimal'], best['saved_decimal']))
PY
echo 'v1634 result matrix:'
cat "$work/matrix.csv"
