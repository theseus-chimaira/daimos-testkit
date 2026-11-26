#!/bin/sh
# Build, switch and relink the real PURE MRES against the real KCORE.
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/pure-directory-package-v1983.XXXXXX")
trap 'echo "v1983 package evidence: $work"' EXIT
for compiler in ${V1983_COMPILERS:-gcc kcc}; do
    b="$work/$compiler"
    mkdir -p "$b"
    build() {
        make -s -C "$DAIMOS_REPO/system/boot/pdp6" "$b/purev1612-mres.dobj" \
            BUILD="$b" PDP10_PREFIX="$PDP10_PREFIX" ROOT=tape BOOT=dtc \
            BOOT_PROFILE=lowmem COMPILER="$compiler" BOOT_CORE_WORDS=0200000 \
            SIMH_CPU_KWORDS=64 TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
            DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_SWAPLESS_ONLY_V1668=1 "$@"
    }
    for mode in 1 0 1; do
        echo "v1983 $compiler directory=$mode"
        build DAIMOS_PBM_DIRECTORY_V1983="$mode" >"$b/build-$mode.log" 2>&1 || {
            tail -80 "$b/build-$mode.log"; exit 1;
        }
        "$PDP10_PREFIX/bin/pdp10-objdump" -h "$b/purev1612-mres.dobj"
        python3 - "$b" "$mode" <<'PY'
from pathlib import Path
import sys
b=Path(sys.argv[1]); mode=int(sys.argv[2])
s=set(line.split()[0] for line in (b/'pure-mres-v1612.map').read_text().splitlines() if line.split())
k=set(line.split()[0] for line in (b/'kcore.map').read_text().splitlines() if line.split())
new={'proc_pure_term_v1982','proc_pure_bitmap_drop_v1979','proc_pure_bitmap_restore_v1980','pbmd_walk_v1977','pbmd_verify_v1979','mm_pure_bitmap_commit_v1979','mm_pure_bitmap_finish_v1664'}
assert not (new & k), 'directory code in fixed KCORE'
assert not ({'bitmap_decode_v1451','proc_pure_bitmap_restore_v1664','proc_pure_term_v1667'} & s)
assert new <= s if mode else not (new & s)
assert 'pdp6_pure_detach_v1609' in s
for f in ('kcore.dxr','purev1612-mres.dobj','pure-mres-v1612.map'):
    saved=b/('mode-%d-'%mode+f)
    if saved.exists(): assert saved.read_bytes()==(b/f).read_bytes(), 'nonreproducible mode switch: '+f
    else: saved.write_bytes((b/f).read_bytes())
PY
    done
    if build DAIMOS_PBM_DIRECTORY_V1983=1 DAIMOS_PBM_V1667=1 >"$b/conflict.log" 2>&1; then
        echo 'FAIL obsolete format accepted'; exit 1
    fi
    grep -q 'directory bitmap requires' "$b/conflict.log"
    if build DAIMOS_PBM_DIRECTORY_V1983=1 DAIMOS_SWAPLESS_ONLY_V1668=0 >"$b/disk.log" 2>&1; then
        echo 'FAIL nonstrict directory build accepted'; exit 1
    fi
    grep -q 'directory bitmap requires' "$b/disk.log"
    echo "PASS v1983 $compiler source-built package and reproducible switching"
done
