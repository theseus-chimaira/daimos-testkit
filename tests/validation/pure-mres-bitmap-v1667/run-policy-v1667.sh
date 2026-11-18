#!/bin/sh
# Guard opt-in mode3 sources to PURE MRES and TSFS-capable KINIT.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-pure-mres-policy-v1667.XXXXXX")
trap 'echo "v1667 build-policy evidence: $work"' EXIT HUP INT TERM
makefile="$DAIMOS_REPO/system/boot/pdp6"

for root in auto tape; do
    make -s -C "$makefile" ROOT="$root" \
        DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_PBM_V1667=1 \
        --eval='print-v1667: ; @printf "%s\n" "$(MRES_PACKAGE_OBJS)"' \
        print-v1667 >"$work/$root-enabled.log"
    grep -q 'purev1612-mres.dobj' "$work/$root-enabled.log" || {
        echo "FAIL v1667: ROOT=$root missing PURE MRES" >&2; exit 1;
    }
    echo "v1667: stage ROOT=$root PURE=1 permitted"
done

for case in 'disk 1' 'drum 1' 'tape 0' 'auto 0'; do
    set -- $case
    root=$1
    pure=$2
    if make -s -C "$makefile" ROOT="$root" \
        DAIMOS_PURE_MRES_ENABLED="$pure" DAIMOS_PBM_V1667=1 \
        --eval='print-v1667: ; @printf "%s\n" "$(MRES_PACKAGE_OBJS)"' \
        print-v1667 >"$work/$root-pure$pure.log" 2>&1; then
        echo "FAIL v1667: stage accepted incompatible $root/$pure" >&2
        exit 1
    fi
    grep -q 'DAIMOS_PBM_V1667 requires TSFS-capable PURE MRES' \
        "$work/$root-pure$pure.log" || {
        tail -30 "$work/$root-pure$pure.log" >&2; exit 1;
    }
    echo "v1667: invalid ROOT=$root PURE=$pure rejected"
done

# Verify the actual linked source symbol ownership. These sources
# cannot silently move to fixed KCORE or the DISK MRES.
: "${V1667_FULL_STAGE:?v1667 FULL auto stage build directory}"
: "${V1667_FULL_BASE:?v1666 FULL auto base build directory}"
: "${V1667_GCC_STAGE:?v1667 GCC lowmem stage build directory}"
: "${V1667_GCC_BASE:?v1666 GCC lowmem base build directory}"
python3 - "$V1667_FULL_STAGE" "$V1667_FULL_BASE" \
    "$V1667_GCC_STAGE" "$V1667_GCC_BASE" <<'PY'
from pathlib import Path
import re
import sys


def lookup(path, symbol):
    source = path.read_text(encoding='ascii')
    matches = re.findall(r'^'+re.escape(symbol)+r'\s+([0-7]+)\s*$',
                         source, re.M)
    if len(matches)!=1:
        raise SystemExit('v1667 missing/duplicate '+symbol+' in '+str(path))
    return int(matches[0],8)


for stage,base,label in ((Path(sys.argv[1]),Path(sys.argv[2]),'KCC FULL'),
                         (Path(sys.argv[3]),Path(sys.argv[4]),'GCC LOWMEM')):
    fixed=lookup(stage/'kcore.map','__kcore_low_end')
    old=lookup(base/'kcore.map','__kcore_low_end')
    if fixed!=old:
        raise SystemExit('FAIL v1667 '+label+' fixed KCORE grew')
    pure=(stage/'pure-mres-v1612.map').read_text(encoding='ascii')
    disk=(stage/'swap-mres-v481.map').read_text(encoding='ascii')
    kcore=(stage/'kcore.map').read_text(encoding='ascii')
    for name in ('proc_pure_term_v1667',
                 'proc_pure_bitmap_terminal_v1661',
                 'proc_pure_bitmap_restore_v1664',
                 'proc_pure_bitmap_retry_v1667',
                 'proc_pure_bitmap_decode_v1660',
                 'mm_pure_bitmap_finish_v1664',
                 'bitmap_decode_v1451'):
        if not re.search('^'+name+r'\s+', pure, re.M) or \
            re.search('^'+name+r'\s+', kcore, re.M) or \
            re.search('^'+name+r'\s+', disk, re.M):
            raise SystemExit('FAIL v1667 '+label+' mislinked '+name)
    print('v1667 '+label+': fixed KCORE unchanged, all bitmap symbols PURE-only PASS')
PY
